#import "XBTabContainerViewController.h"
#import <Masonry/Masonry.h>

/// 区分容器自身的展示阶段，避免切 Tab 时给不可见页面发送出现事件或重复启动定时器。
typedef NS_ENUM(NSUInteger, XBTabContainerAppearancePhase) {
    XBTabContainerAppearancePhaseHidden,       ///< 容器未显示，切 Tab 只更新视图和选中项。
    XBTabContainerAppearancePhaseAppearing,    ///< 容器正在出现，新选中页接续本轮出现事件。
    XBTabContainerAppearancePhaseVisible,      ///< 容器已显示，切 Tab 成对发送旧页消失和新页出现事件。
    XBTabContainerAppearancePhaseDisappearing, ///< 容器正在消失，切换后的页面不提前接收出现事件。
};

/// UINavigationController 的 delegate 是弱引用。容器持有代理，同时向原代理转发导航动画等回调。
@interface XBTabNavigationDelegate : NSObject <UINavigationControllerDelegate>
@property (nonatomic, weak) XBTabContainerViewController *container;
@property (nonatomic, weak) id<UINavigationControllerDelegate> originalDelegate;
@end

@implementation XBTabNavigationDelegate
/// 先同步底栏，再让接入项目原有的导航代理处理业务或自定义转场。
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [self.container navigationController:navigationController willShowViewController:viewController animated:animated];
    if ([self.originalDelegate respondsToSelector:_cmd]) {
        [self.originalDelegate navigationController:navigationController willShowViewController:viewController animated:animated];
    }
}
/// 转场收尾和侧滑取消使用真实导航栈，原代理仍能收到原始 didShow。
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [self.container navigationController:navigationController didShowViewController:viewController animated:animated];
    if ([self.originalDelegate respondsToSelector:_cmd]) {
        [self.originalDelegate navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}
/// 只在原代理提供这些可选能力时启用，保持系统原来的转场/方向默认行为。
- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(navigationController:animationControllerForOperation:fromViewController:toViewController:) ||
        selector == @selector(navigationController:interactionControllerForAnimationController:) ||
        selector == @selector(navigationControllerSupportedInterfaceOrientations:) ||
        selector == @selector(navigationControllerPreferredInterfaceOrientationForPresentation:)) {
        return [self.originalDelegate respondsToSelector:selector];
    }
    return [super respondsToSelector:selector];
}
/// UIKit 可能缓存代理能力；原代理后来释放时显式返回 nil，不能向已消失的弱对象做动态转发。
- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromViewController toViewController:(UIViewController *)toViewController {
    id<UINavigationControllerDelegate> original = self.originalDelegate;
    if ([original respondsToSelector:_cmd]) {
        return [original navigationController:navigationController animationControllerForOperation:operation fromViewController:fromViewController toViewController:toViewController];
    }
    return nil;
}
/// 保留原交互转场；原代理释放后让 UIKit 使用非交互默认转场。
- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    id<UINavigationControllerDelegate> original = self.originalDelegate;
    if ([original respondsToSelector:_cmd]) {
        return [original navigationController:navigationController interactionControllerForAnimationController:animationController];
    }
    return nil;
}
/// 原项目明确提供方向代理时沿用其结果；弱代理消失后的缓存调用退回当前页面声明。
- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    id<UINavigationControllerDelegate> original = self.originalDelegate;
    if ([original respondsToSelector:_cmd]) {
        return [original navigationControllerSupportedInterfaceOrientations:navigationController];
    }
    return navigationController.topViewController.supportedInterfaceOrientations;
}
/// 首选展示方向同样不抢占接入方原有策略。
- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController {
    id<UINavigationControllerDelegate> original = self.originalDelegate;
    if ([original respondsToSelector:_cmd]) {
        return [original navigationControllerPreferredInterfaceOrientationForPresentation:navigationController];
    }
    return navigationController.topViewController.preferredInterfaceOrientationForPresentation;
}
@end

@interface XBTabContainerViewController ()
/// 仅挂载当前一级页面的视图；其它导航仍为子控制器，但不占用可见视图层级。
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong, readwrite) XBTabBarView *tabBar;
/// 底部栏总高度包含 Home Indicator 安全区域，横竖屏切换时更新同一约束。
@property (nonatomic, strong) MASConstraint *tabBarHeightConstraint;
/// 记录接管前的附加安全区域，隐藏栏或移除页面时恢复，不累计重复增加49点。
@property (nonatomic, strong) NSMapTable<UIViewController *, NSValue *> *originalInsets;
/// 容器当前生命周期阶段，仅当前显示的一级页面参与转发。
@property (nonatomic, assign) XBTabContainerAppearancePhase appearancePhase;
/// 等待容器 didAppear/didDisappear 收尾的页面；切换选中页前先结束其事件对。
@property (nonatomic, strong, nullable) UIViewController *pendingAppearanceController;
@property (nonatomic, assign, readwrite, getter=isTabBarHidden) BOOL tabBarHidden;
/// 移除入口时恢复接入方原有的导航代理，不把代理对象泄漏到已脱离的导航栈。
@property (nonatomic, strong) NSMapTable<UINavigationController *, XBTabNavigationDelegate *> *navigationDelegates;
/// 防止 shouldSelect 中同步发起另一次选择导致递归；异步登录后可重新调用选择入口。
@property (nonatomic, assign) BOOL handlingSelection;
/// 页面可在挂窗前配置；暂存按钮数据，避免配置阶段访问 tabBar 导致子类 viewDidLoad 递归重建。
@property (nonatomic, copy) NSArray<XBTabBarItem *> *configuredItems;
/// 默认入口身份跟随控制器对象，重排时不使用位置生成身份；弱键不延长页面生命周期。
@property (nonatomic, strong) NSMapTable<UIViewController *, NSString *> *defaultIdentifiers;
@end

@implementation XBTabContainerViewController
@synthesize tabBarAppearance = _tabBarAppearance;

/// 无页面时保持显式的未选中状态，不让下标0误指向尚未创建的业务页。
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self xb_initializeContainer];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self xb_initializeContainer];
    }
    return self;
}

/// 代码和 Storyboard/XIB 使用相同的初始状态；入口配置仍由接入方提供。
- (void)xb_initializeContainer {
    if (_originalInsets == nil) {
        _viewControllers = @[];
        _selectedIndex = NSNotFound;
        _originalInsets = [NSMapTable weakToStrongObjectsMapTable];
        _navigationDelegates = [NSMapTable weakToStrongObjectsMapTable];
        _tabBarAppearance = [XBTabBarAppearance new];
        _configuredItems = @[];
        _defaultIdentifiers = [NSMapTable weakToStrongObjectsMapTable];
    }
}

/// 容器只管理内容宿主和底部宿主，按钮样式及权限判断留给业务层。
- (void)viewDidLoad {
    [super viewDidLoad];
    self.contentView = [UIView new];
    _tabBar = [XBTabBarView new];
    _tabBar.appearance = _tabBarAppearance;
    [_tabBar setItems:self.configuredItems];
    __weak typeof(self) weakSelf = self;
    _tabBar.itemTapHandler = ^(NSString *identifier, NSUInteger index) {
        [weakSelf selectTabWithIdentifier:identifier];
    };
    [self.view addSubview:self.contentView];
    [self.view addSubview:_tabBar];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [_tabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        self.tabBarHeightConstraint = make.height.mas_equalTo(_tabBarAppearance.contentHeight);
    }];
    [self displayViewController:self.selectedViewController replacing:nil];
}

/// 允许先构建页面再访问底部宿主，避免外部提前配置时得到空宿主。
- (XBTabBarView *)tabBar {
    [self loadViewIfNeeded];
    return _tabBar;
}

/// 重建时按对象保留仍存在的选中页；移除的页面恢复原安全区域并退出父容器。
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers {
    NSMutableArray<XBTabBarItem *> *items = [NSMutableArray array];
    for (NSUInteger index = 0; index < viewControllers.count; index++) {
        UIViewController *controller = viewControllers[index];
        UITabBarItem *source = controller.tabBarItem;
        NSString *identifier = controller.restorationIdentifier;
        if (identifier.length == 0) {
            identifier = [self.defaultIdentifiers objectForKey:controller];
            if (identifier == nil) {
                identifier = [@"XBTabBar.auto." stringByAppendingString:NSUUID.UUID.UUIDString];
                [self.defaultIdentifiers setObject:identifier forKey:controller];
            }
        }
        XBTabBarItem *item = [[XBTabBarItem alloc] initWithIdentifier:identifier title:source.title ?: controller.title ?: @"" image:source.image selectedImage:source.selectedImage];
        item.badgeValue = source.badgeValue;
        [items addObject:item];
    }
    [self setViewControllers:viewControllers tabBarItems:items];
}

/// 一次替换页面和按钮，避免数量更新到一半时出现越界；稳定标识优先于旧数组下标。
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers tabBarItems:(NSArray<XBTabBarItem *> *)items {
    NSMutableSet *identifiers = [NSMutableSet set];
    BOOL valid = [NSSet setWithArray:viewControllers].count == viewControllers.count;
    NSUInteger pageCount = 0;
    for (XBTabBarItem *item in items) {
        if (item.identifier.length == 0 || [identifiers containsObject:item.identifier] ||
            (item.kind != XBTabBarItemKindPage && item.kind != XBTabBarItemKindAction)) {
            valid = NO;
            break;
        }
        [identifiers addObject:item.identifier];
        if (item.kind == XBTabBarItemKindPage) {
            pageCount++;
        }
    }
    valid = valid && viewControllers.count == pageCount;
    for (UIViewController *controller in viewControllers) {
        valid = valid && (controller.parentViewController == nil || controller.parentViewController == self);
        for (UIViewController *ancestor = self; ancestor != nil; ancestor = ancestor.parentViewController) {
            valid = valid && controller != ancestor;
        }
    }
    NSAssert(valid, @"Page items must match controller count; identifiers/controllers must be unique and controllers must belong to this container or no container");
    if (!valid) {
        return;
    }
    NSUInteger previousItemIndex = [self itemIndexForPageIndex:self.selectedIndex];
    NSString *previousIdentifier = previousItemIndex != NSNotFound ? self.configuredItems[previousItemIndex].identifier : nil;
    NSArray<UIViewController *> *previousControllers = _viewControllers;
    UIViewController *previousSelection = self.selectedViewController;
    NSArray<UIViewController *> *controllers = [viewControllers copy] ?: @[];
    for (UIViewController *controller in previousControllers) {
        if (![controllers containsObject:controller]) {
            [controller willMoveToParentViewController:nil];
        }
    }
    for (UIViewController *controller in controllers) {
        if (controller.parentViewController != self) {
            [self.originalInsets setObject:[NSValue valueWithUIEdgeInsets:controller.additionalSafeAreaInsets] forKey:controller];
            [self addChildViewController:controller];
            if ([controller isKindOfClass:UINavigationController.class]) {
                UINavigationController *navigation = (UINavigationController *)controller;
                XBTabNavigationDelegate *proxy = [XBTabNavigationDelegate new];
                proxy.container = self;
                proxy.originalDelegate = navigation.delegate;
                [self.navigationDelegates setObject:proxy forKey:navigation];
                navigation.delegate = proxy;
            }
            [controller didMoveToParentViewController:self];
        }
    }
    _viewControllers = controllers;
    self.configuredItems = [[NSArray alloc] initWithArray:items copyItems:YES];
    if (self.isViewLoaded && self.contentView != nil) {
        [self.tabBar setItems:items];
    }
    NSUInteger index = [controllers indexOfObjectIdenticalTo:previousSelection];
    NSUInteger identifierIndex = [items indexOfObjectPassingTest:^BOOL(XBTabBarItem *item, NSUInteger idx, BOOL *stop) {
        return [item.identifier isEqualToString:previousIdentifier];
    }];
    NSUInteger pageIndex = [self pageIndexForItemIndex:identifierIndex];
    if (pageIndex != NSNotFound) {
        index = pageIndex;
    }
    if (index == NSNotFound && controllers.count > 0) {
        index = 0;
    }
    _selectedIndex = index;
    UIViewController *selection = index == NSNotFound ? nil : controllers[index];
    [self displayViewController:selection replacing:previousSelection];
    for (UIViewController *controller in previousControllers) {
        if (![controllers containsObject:controller]) {
            if ([controller isKindOfClass:UINavigationController.class]) {
                UINavigationController *navigation = (UINavigationController *)controller;
                XBTabNavigationDelegate *proxy = [self.navigationDelegates objectForKey:navigation];
                if (navigation.delegate == proxy) {
                    navigation.delegate = proxy.originalDelegate;
                }
                [self.navigationDelegates removeObjectForKey:navigation];
            }
            controller.additionalSafeAreaInsets = [[self.originalInsets objectForKey:controller] UIEdgeInsetsValue];
            [self.originalInsets removeObjectForKey:controller];
            [controller.viewIfLoaded removeFromSuperview];
            [controller removeFromParentViewController];
        }
    }
}

/// 页面下标只计算 Page，操作按钮插入/重排后仍按相同语义读取 viewControllers。
- (NSUInteger)itemIndexForPageIndex:(NSUInteger)pageIndex {
    NSUInteger currentPage = 0;
    for (NSUInteger itemIndex = 0; itemIndex < self.configuredItems.count; itemIndex++) {
        if (self.configuredItems[itemIndex].kind == XBTabBarItemKindPage) {
            if (currentPage == pageIndex) {
                return itemIndex;
            }
            currentPage++;
        }
    }
    return NSNotFound;
}

/// 反向映射仅接受页面入口；Action 或越界位置不对应任何控制器。
- (NSUInteger)pageIndexForItemIndex:(NSUInteger)itemIndex {
    if (itemIndex >= self.configuredItems.count || self.configuredItems[itemIndex].kind != XBTabBarItemKindPage) {
        return NSNotFound;
    }
    NSUInteger pageIndex = 0;
    for (NSUInteger index = 0; index < itemIndex; index++) {
        if (self.configuredItems[index].kind == XBTabBarItemKindPage) {
            pageIndex++;
        }
    }
    return pageIndex;
}

/// 页面切换没有系统按钮参与，选中项与实际挂载的页面在同一调用中更新。
- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    if (selectedIndex >= self.viewControllers.count) {
        return;
    }
    UIViewController *previous = self.selectedViewController;
    _selectedIndex = selectedIndex;
    [self displayViewController:self.viewControllers[selectedIndex] replacing:previous];
}

/// 对象选择复用下标出口，使外部代码和按钮选择得到一致的状态刷新。
- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    NSUInteger index = [self.viewControllers indexOfObjectIdenticalTo:selectedViewController];
    if (index != NSNotFound) {
        self.selectedIndex = index;
    }
}

/// 只有显示阶段才发送切页生命周期；容器出现到一半时接续新页面，消失阶段不启动新页面。
- (void)displayViewController:(UIViewController *)controller replacing:(UIViewController *)previous {
    _selectedViewController = controller;
    _tabBar.selectedIndex = [self itemIndexForPageIndex:self.selectedIndex];
    if (!self.isViewLoaded || self.contentView == nil) {
        return;
    }
    if (controller == previous && controller.viewIfLoaded.superview == self.contentView) {
        return;
    }
    [self finishPendingAppearanceTransition];
    BOOL forwardsAppearance = self.appearancePhase == XBTabContainerAppearancePhaseVisible ||
        self.appearancePhase == XBTabContainerAppearancePhaseAppearing;
    if (forwardsAppearance) {
        [previous beginAppearanceTransition:NO animated:NO];
        [controller beginAppearanceTransition:YES animated:NO];
    }
    [previous.viewIfLoaded removeFromSuperview];
    if (controller) {
        [self.contentView addSubview:controller.view];
        [controller.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
    if (forwardsAppearance) {
        [previous endAppearanceTransition];
        if (self.appearancePhase == XBTabContainerAppearancePhaseAppearing) {
            self.pendingAppearanceController = controller;
        } else {
            [controller endAppearanceTransition];
        }
    }
    BOOL hidden = [self shouldHideTabBarForNavigationController:self.currentNavigationController destination:self.currentNavigationController.topViewController];
    [self setTabBarHidden:hidden animated:NO];
    [self setNeedsStatusBarAppearanceUpdate];
}

/// 每个入口直接返回自己的导航，不按第几个入口分支。
- (UINavigationController *)currentNavigationController {
    if ([self.selectedViewController isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)self.selectedViewController;
    }
    return self.selectedViewController.navigationController;
}

/// 自动转发会影响尚未显示的其它子导航，因此由容器明确转发给当前页。
- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

/// 出现阶段先登记待收尾页面，再交给业务页执行 viewWillAppear。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self finishPendingAppearanceTransition];
    self.appearancePhase = XBTabContainerAppearancePhaseAppearing;
    self.pendingAppearanceController = self.selectedViewController;
    [self.pendingAppearanceController beginAppearanceTransition:YES animated:animated];
}

/// 完成当前页面的出现事件，确保只启动当前入口的可见态任务。
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self finishPendingAppearanceTransition];
    self.appearancePhase = XBTabContainerAppearancePhaseVisible;
}

/// 被全屏页面盖住时，及时通知当前入口停止仅可见时执行的任务。
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self finishPendingAppearanceTransition];
    self.appearancePhase = XBTabContainerAppearancePhaseDisappearing;
    self.pendingAppearanceController = self.selectedViewController;
    [self.pendingAppearanceController beginAppearanceTransition:NO animated:animated];
}

/// 消失事件收尾；此后修改选中页不会误启动新页面的刷新。
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self finishPendingAppearanceTransition];
    self.appearancePhase = XBTabContainerAppearancePhaseHidden;
}

/// 结束并清空尚未配对的出现/消失事件，防止重建或快速切换留下未结束的生命周期。
- (void)finishPendingAppearanceTransition {
    UIViewController *controller = self.pendingAppearanceController;
    self.pendingAppearanceController = nil;
    [controller endAppearanceTransition];
}

/// 沿目标页面之前的导航栈判断隐藏状态，与 hidesBottomBarWhenPushed 的栈继承语义一致。
- (BOOL)shouldHideTabBarForNavigationController:(UINavigationController *)navigation destination:(UIViewController *)destination {
    for (UIViewController *controller in navigation.viewControllers) {
        if (controller != navigation.viewControllers.firstObject && controller.hidesBottomBarWhenPushed) {
            return YES;
        }
        if (controller == destination) {
            break;
        }
    }
    return NO;
}

/// 一起更新栏位移和内容安全区域，详情页不会残留底部49点空白。
- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animated {
    _tabBarHidden = hidden;
    if (!self.isViewLoaded) {
        return;
    }
    void (^changes)(void) = ^{
        self->_tabBar.transform = hidden ? CGAffineTransformMakeTranslation(0, CGRectGetHeight(self->_tabBar.bounds)) : CGAffineTransformIdentity;
        UIViewController *controller = self.selectedViewController;
        if (controller) {
            UIEdgeInsets insets = controller.additionalSafeAreaInsets;
            insets.bottom = [[self.originalInsets objectForKey:controller] UIEdgeInsetsValue].bottom + (hidden ? 0 : self->_tabBarAppearance.contentHeight);
            controller.additionalSafeAreaInsets = insets;
        }
    };
    _tabBar.hidden = NO;
    if (animated) {
        [UIView animateWithDuration:0.25 animations:changes completion:^(BOOL finished) {
            self->_tabBar.hidden = self.tabBarHidden;
        }];
    } else {
        changes();
        _tabBar.hidden = hidden;
    }
}

/// 跟随 push/pop 的同一转场更新底部栏；交互返回取消后恢复当前真实栈顶的状态。
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (navigationController != self.currentNavigationController) {
        return;
    }
    BOOL hidden = [self shouldHideTabBarForNavigationController:navigationController destination:viewController];
    id<UIViewControllerTransitionCoordinator> coordinator = navigationController.transitionCoordinator;
    if (animated && coordinator) {
        __weak typeof(self) weakSelf = self;
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            [weakSelf setTabBarHidden:hidden animated:NO];
            // 转场过程中只移动栏，不立即隐藏；待完成/取消后再按真实栈顶收尾，侧滑时栏才能跟手。
            weakSelf.tabBar.hidden = NO;
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (navigationController == weakSelf.currentNavigationController) {
                BOOL actualHidden = [weakSelf shouldHideTabBarForNavigationController:navigationController destination:navigationController.topViewController];
                [weakSelf setTabBarHidden:actualHidden animated:NO];
            }
        }];
    } else {
        [self setTabBarHidden:hidden animated:NO];
    }
    [self setNeedsStatusBarAppearanceUpdate];
}

/// 以真实导航栈顶兜底，覆盖非动画返回及交互返回取消，不留下栏显示状态错位。
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (navigationController == self.currentNavigationController) {
        BOOL hidden = [self shouldHideTabBarForNavigationController:navigationController destination:viewController];
        [self setTabBarHidden:hidden animated:NO];
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

/// 安全区域变化只更新宿主高度，导航内容的额外避让始终为按钮区49点。
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.tabBarHeightConstraint setOffset:_tabBarAppearance.contentHeight + self.view.safeAreaInsets.bottom];
}

/// 外观变化只更新按钮与安全区，不重建导航栈；高度由容器负责统一，避免宿主与按钮区不一致。
- (XBTabBarAppearance *)tabBarAppearance {
    return [_tabBarAppearance copy];
}

- (void)setTabBarAppearance:(XBTabBarAppearance *)tabBarAppearance {
    _tabBarAppearance = [tabBarAppearance copy];
    if (_tabBarAppearance.contentHeight <= 0) {
        _tabBarAppearance.contentHeight = 49;
    }
    if (self.isViewLoaded) {
        self.tabBar.appearance = _tabBarAppearance;
        [self.tabBarHeightConstraint setOffset:_tabBarAppearance.contentHeight + self.view.safeAreaInsets.bottom];
        [self setTabBarHidden:self.tabBarHidden animated:NO];
    }
}

/// 一、按标识找入口；二、业务准入；三、提交选择；四、通知重复点击/动画。静默 setter 不走此链。
- (BOOL)selectTabWithIdentifier:(NSString *)identifier {
    if (self.handlingSelection) {
        return NO;
    }
    NSArray<XBTabBarItem *> *items = self.tabBar.items;
    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(XBTabBarItem *item, NSUInteger idx, BOOL *stop) {
        return [item.identifier isEqualToString:identifier];
    }];
    if (index == NSNotFound || !items[index].isEnabled) {
        return NO;
    }
    self.handlingSelection = YES;
    XBTabBarItem *item = items[index];
    // 一次激活使用同一个接收者；准入或动画回调即使更换 delegate，也不会把收尾发给未参与准入的新对象。
    id<XBTabContainerDelegate> delegate = self.selectionDelegate;
    if (item.kind == XBTabBarItemKindAction && ![delegate respondsToSelector:@selector(tabContainer:didTriggerActionItem:atIndex:)]) {
        self.handlingSelection = NO;
        return NO;
    }
    BOOL accepted = YES;
    if ([delegate respondsToSelector:@selector(tabContainer:shouldSelectItem:atIndex:)]) {
        accepted = [delegate tabContainer:self shouldSelectItem:item atIndex:index];
    }
    // 准入可能同步重建入口，旧按钮不能再按过期位置切页。
    items = self.tabBar.items;
    accepted = accepted && index < items.count && [items[index].identifier isEqualToString:identifier] &&
        items[index].kind == item.kind && items[index].isEnabled;
    if (accepted) {
        if (item.kind == XBTabBarItemKindAction) {
            [self.tabBar animateSelectionAtIndex:index reselected:NO];
            [delegate tabContainer:self didTriggerActionItem:item atIndex:index];
        } else {
            NSUInteger pageIndex = [self pageIndexForItemIndex:index];
            BOOL reselected = self.selectedIndex == pageIndex;
            if (!reselected) {
                self.selectedIndex = pageIndex;
            }
            [self.tabBar animateSelectionAtIndex:index reselected:reselected];
            if ([delegate respondsToSelector:@selector(tabContainer:didSelectItem:atIndex:reselected:)]) {
                [delegate tabContainer:self didSelectItem:item atIndex:index reselected:reselected];
            }
        }
    }
    self.handlingSelection = NO;
    return accepted;
}

/// 状态栏文字颜色交给当前导航继续向顶部业务页转发。
- (UIViewController *)childViewControllerForStatusBarStyle {
    return self.selectedViewController;
}
/// 状态栏是否隐藏由当前入口决定，其它后台入口不能影响它。
- (UIViewController *)childViewControllerForStatusBarHidden {
    return self.selectedViewController;
}
/// 播放器等页面可自行隐藏 Home Indicator，容器不强制覆盖。
- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden {
    return self.selectedViewController;
}
/// 保留直接读取根容器状态栏样式的旧调用方式。
- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.selectedViewController.preferredStatusBarStyle;
}
/// 是否允许旋转由当前入口决定，不使用后台页面的方向配置。
- (BOOL)shouldAutorotate {
    return self.selectedViewController ? self.selectedViewController.shouldAutorotate : YES;
}
/// 当前入口提供支持的方向；尚无页面时使用竖屏，避免启动期间意外旋转。
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.selectedViewController ? self.selectedViewController.supportedInterfaceOrientations : UIInterfaceOrientationMaskPortrait;
}
/// 容器被模态展示时，以当前入口的首选方向作为起始方向。
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return self.selectedViewController ? self.selectedViewController.preferredInterfaceOrientationForPresentation : UIInterfaceOrientationPortrait;
}

/// 容器释放但导航被外部保留时，也恢复原代理及附加避让，不留下指向失效代理的弱引用。
- (void)dealloc {
    for (UINavigationController *navigation in self.navigationDelegates) {
        XBTabNavigationDelegate *proxy = [self.navigationDelegates objectForKey:navigation];
        if (navigation.delegate == proxy) {
            navigation.delegate = proxy.originalDelegate;
        }
    }
    for (UIViewController *controller in self.originalInsets) {
        controller.additionalSafeAreaInsets = [[self.originalInsets objectForKey:controller] UIEdgeInsetsValue];
    }
}

@end

@implementation UIViewController (XBTabContainer)
/// 详情页沿父导航找到容器，模态页则沿 presenting 关系继续查找，不依赖全局 keyWindow。
- (XBTabContainerViewController *)xb_tabContainer {
    UIViewController *controller = self;
    while (controller) {
        if ([controller isKindOfClass:XBTabContainerViewController.class]) {
            return (XBTabContainerViewController *)controller;
        }
        controller = controller.parentViewController ?: controller.presentingViewController;
    }
    return nil;
}
@end

/// 公共层可以同时兼容新业务容器与仍在使用系统 Tab 的旧页面。
UIViewController *XBSelectedTabViewController(UIViewController *controller) {
    if ([controller isKindOfClass:XBTabContainerViewController.class]) {
        return ((XBTabContainerViewController *)controller).selectedViewController;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return ((UITabBarController *)controller).selectedViewController;
    }
    return nil;
}
