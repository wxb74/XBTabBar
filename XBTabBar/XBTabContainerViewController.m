#import "XBTabContainerViewController.h"
#import <Masonry/Masonry.h>
#if __has_include(<UIKit/UIVerticalBarEdge.h>)
#import <UIKit/UIVerticalBarEdge.h>
#endif

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
/// 已解析的物理栏位置与当前页面的额外避让。
@property (nonatomic, assign, readwrite) XBTabBarPlacement resolvedTabBarPlacement;
@property (nonatomic, assign, readwrite) UIEdgeInsets tabBarContentInsets;
@property (nonatomic, strong) NSMapTable<UIViewController *, NSValue *> *managedInsets;
@property (nonatomic, assign) BOOL updatingBarLayout;
@property (nonatomic, assign) BOOL animatingBarVisibility;
@property (nonatomic, assign) CGRect keyboardFrameInScreen;
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
    if (_managedInsets == nil) {
        _viewControllers = @[];
        _keyboardFrameInScreen = CGRectNull;
        _selectedIndex = NSNotFound;
        _managedInsets = [NSMapTable weakToStrongObjectsMapTable];
        _navigationDelegates = [NSMapTable weakToStrongObjectsMapTable];
        _tabBarAppearance = [XBTabBarAppearance new];
        _configuredItems = @[];
        _defaultIdentifiers = [NSMapTable weakToStrongObjectsMapTable];
    }
}

/// 内容背景铺满宿主，交互内容通过安全区避让栏；这里不裁剪业务页或重建导航栈。
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
    for (NSNotificationName name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardDidChangeFrameNotification, UIKeyboardWillHideNotification, UIKeyboardDidHideNotification]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:name object:nil];
    }
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        [self registerForTraitChanges:UITraitCollection.systemTraitsAffectingVerticalBarEdge
                         withHandler:^(XBTabContainerViewController *environment, UITraitCollection *previous) {
            [environment.view setNeedsLayout];
        }];
    }
#endif
    [self displayViewController:self.selectedViewController replacing:nil];
}

/// 访问按钮栏会加载视图；入口可在此之前通过 setViewControllers:tabBarItems: 配置。
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
            [self applyManagedInsets:UIEdgeInsetsZero toController:controller];
            [self.managedInsets removeObjectForKey:controller];
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
    // 离窗期间可能错过键盘收起通知；重新展示时以当前窗口的键盘 guide 为准。
    self.keyboardFrameInScreen = CGRectNull;
    [self.view setNeedsLayout];
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

/// 隐藏状态和附加避让同步更新，详情页不残留底部或侧边的栏占位。
- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animated {
    _tabBarHidden = hidden;
    if (!self.isViewLoaded) {
        return;
    }
    void (^changes)(void) = ^{
        [self updateTabBarLayout];
    };
    _tabBar.hidden = NO;
    self.animatingBarVisibility = animated && !UIAccessibilityIsReduceMotionEnabled();
    if (self.animatingBarVisibility) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:changes completion:^(BOOL finished) {
            self.animatingBarVisibility = NO;
            [self updateTabBarLayout];
        }];
    } else {
        changes();
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

/// 系统安全区变化时重新分配底部或侧边避让，业务页面无需重复计算栏尺寸。
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self updateTabBarLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateTabBarLayout];
}

- (void)setTabBarPlacement:(XBTabBarPlacement)tabBarPlacement {
    if (_tabBarPlacement == tabBarPlacement) return;
    _tabBarPlacement = tabBarPlacement;
    if (self.isViewLoaded) [self updateTabBarLayout];
}

/// 键盘 guide 的最终值可能晚于页面布局回调，帧通知负责驱动这次布局更新。
- (void)keyboardFrameDidChange:(NSNotification *)notification {
    if (!self.viewIfLoaded.window) return;
    NSValue *value = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
    self.keyboardFrameInScreen = value ? value.CGRectValue : CGRectNull;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    BOOL startsTransition = [notification.name isEqualToString:UIKeyboardWillChangeFrameNotification] || [notification.name isEqualToString:UIKeyboardWillHideNotification];
    if (startsTransition && duration > 0 && !UIAccessibilityIsReduceMotionEnabled()) {
        UIViewAnimationOptions curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
        [UIView animateWithDuration:duration delay:0 options:curve | UIViewAnimationOptionBeginFromCurrentState animations:^{
            [self updateTabBarLayout];
            [self->_tabBar layoutIfNeeded];
        } completion:nil];
    } else {
        [self updateTabBarLayout];
    }
}

/// 只撤回容器自己上次增加的值，保留业务在运行中调整的其它附加边距。
- (void)applyManagedInsets:(UIEdgeInsets)managed toController:(UIViewController *)controller {
    if (!controller) return;
    UIEdgeInsets previous = [[self.managedInsets objectForKey:controller] UIEdgeInsetsValue];
    UIEdgeInsets insets = controller.additionalSafeAreaInsets;
    insets.left += managed.left - previous.left;
    insets.right += managed.right - previous.right;
    insets.bottom += managed.bottom - previous.bottom;
    [self.managedInsets setObject:[NSValue valueWithUIEdgeInsets:managed] forKey:controller];
    if (!UIEdgeInsetsEqualToEdgeInsets(insets, controller.additionalSafeAreaInsets)) controller.additionalSafeAreaInsets = insets;
}

/// 在侧边列中切除相机和当前活跃折叠区域；不以屏幕中点猜测铰链。
- (CGRect)availableFloatingColumn:(CGRect)column {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        NSMutableArray<NSValue *> *segments = [NSMutableArray arrayWithObject:[NSValue valueWithCGRect:column]];
        NSArray *regions = [[self.view reservedRegionsOfKind:UIViewReservedRegionKind.occlusionRegionKind]
            arrayByAddingObjectsFromArray:[self.view reservedRegionsOfKind:UIViewReservedRegionKind.divisionRegionKind]];
        for (UIViewReservedRegion *region in regions) {
            if (!region.active) continue;
            NSMutableArray *next = [NSMutableArray array];
            for (NSValue *value in segments) {
                CGRect segment = value.CGRectValue, intersection = CGRectIntersection(segment, region.frame);
                if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) { [next addObject:value]; continue; }
                CGFloat topHeight = CGRectGetMinY(intersection) - CGRectGetMinY(segment);
                CGFloat bottomY = CGRectGetMaxY(intersection);
                if (topHeight > 0) [next addObject:[NSValue valueWithCGRect:CGRectMake(segment.origin.x, segment.origin.y, segment.size.width, topHeight)]];
                if (bottomY < CGRectGetMaxY(segment)) [next addObject:[NSValue valueWithCGRect:CGRectMake(segment.origin.x, bottomY, segment.size.width, CGRectGetMaxY(segment) - bottomY)]];
            }
            segments = next;
        }
        // 至少容纳一整项和上下各8pt内边距；使用接入方配置的行高，不压缩点击区域。
        CGFloat minimumHeight = MAX(44, _tabBarAppearance.floatingItemHeight) + 16;
        for (NSValue *value in segments.reverseObjectEnumerator) {
            if (value.CGRectValue.size.height >= minimumHeight) return value.CGRectValue;
        }
        return CGRectZero;
    }
#endif
    return column;
}

/// 几何变化只改栏和附加安全区，不重建页面、导航栈或按钮。
- (void)updateTabBarLayout {
    if (self.updatingBarLayout || !_tabBar || !self.contentView) return;
    self.updatingBarLayout = YES;
    XBTabBarPlacement placement = self.tabBarPlacement == XBTabBarPlacementAutomatic ? XBTabBarPlacementForTraits(self.traitCollection) : self.tabBarPlacement;
    self.resolvedTabBarPlacement = placement;
    BOOL vertical = placement == XBTabBarPlacementFloatingLeft || placement == XBTabBarPlacementFloatingRight;
    _tabBar.vertical = vertical;
    CGRect bounds = self.view.bounds;
    UIEdgeInsets safe = self.view.safeAreaInsets, managed = UIEdgeInsetsZero;
    CGFloat minimumFloatingHeight = MAX(44, _tabBarAppearance.floatingItemHeight) + 16;
    CGRect frame;
    if (vertical) {
        CGFloat width = MAX(44, _tabBarAppearance.floatingWidth), margin = MAX(0, _tabBarAppearance.floatingMargin);
        UIEdgeInsets dockingInsets = safe;
        // 系统给垂直栏预留的侧边安全区就是栏的宿主，不再把胶囊放到这条区域内侧。
        // 仅复用系统指定的那一侧；强制布局测试仍保留其它设备真实的侧边物理避让。
        XBTabBarPlacement systemPlacement = XBTabBarPlacementForTraits(self.traitCollection);
        if (placement == systemPlacement) {
            if (placement == XBTabBarPlacementFloatingLeft) dockingInsets.left = 0;
            else dockingInsets.right = 0;
        }
        CGRect available = UIEdgeInsetsInsetRect(bounds, dockingInsets);
        // 极窄的分屏不能让胶囊越出宿主；不足44pt时由下方可见性判断暂时隐藏。
        width = MIN(width, MAX(0, CGRectGetWidth(available) - margin * 2));
        CGFloat top = MAX(CGRectGetMinY(available) + margin, CGRectGetMinY(bounds) + MAX(0, _tabBarAppearance.floatingTopClearance));
        CGFloat x = placement == XBTabBarPlacementFloatingLeft ? CGRectGetMinX(available) + margin : CGRectGetMaxX(available) - margin - width;
        CGRect keyboard = self.view.keyboardLayoutGuide.layoutFrame;
        if (!CGRectIsNull(self.keyboardFrameInScreen) && self.view.window) {
            UIScreen *screen = self.view.window.windowScene.screen ?: self.view.window.screen;
            keyboard = [self.view convertRect:self.keyboardFrameInScreen fromCoordinateSpace:screen.coordinateSpace];
        }
        // 只避让与本窗口侧栏相交的停靠键盘，浮动键盘不把整条栏推走。
        if (!CGRectIsEmpty(keyboard) && CGRectGetMaxY(keyboard) >= CGRectGetMaxY(bounds) - 1 &&
            CGRectGetMaxX(keyboard) > x && CGRectGetMinX(keyboard) < x + width) {
            available.size.height = MAX(0, MIN(CGRectGetMaxY(available), CGRectGetMinY(keyboard)) - available.origin.y);
        }
        CGRect column = CGRectMake(x, top, width, MAX(0, CGRectGetMaxY(available) - margin - top));
        column = [self availableFloatingColumn:column];
        CGFloat height = MIN(column.size.height, self.configuredItems.count * MAX(44, _tabBarAppearance.floatingItemHeight) + 16);
        frame = CGRectMake(column.origin.x, CGRectGetMaxY(column) - height, column.size.width, height);
        if (!self.tabBarHidden && height >= minimumFloatingHeight && width >= 44) {
            if (placement == XBTabBarPlacementFloatingLeft) managed.left = MAX(0, CGRectGetMaxX(frame) + margin - CGRectGetMinX(bounds) - safe.left);
            else managed.right = MAX(0, CGRectGetMaxX(bounds) - CGRectGetMinX(frame) + margin - safe.right);
        }
    } else {
        CGFloat height = _tabBarAppearance.contentHeight + safe.bottom;
        frame = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - height, bounds.size.width, height);
        if (!self.tabBarHidden && self.configuredItems.count) managed.bottom = _tabBarAppearance.contentHeight;
    }
    _tabBar.transform = CGAffineTransformIdentity;
    _tabBar.frame = frame;
    if (self.tabBarHidden) {
        _tabBar.transform = vertical ? CGAffineTransformMakeTranslation((placement == XBTabBarPlacementFloatingLeft ? -1 : 1) * (frame.size.width + _tabBarAppearance.floatingMargin), 0) : CGAffineTransformMakeTranslation(0, frame.size.height);
    }
    _tabBar.hidden = (self.tabBarHidden && !self.animatingBarVisibility) || self.configuredItems.count == 0 || CGRectIsEmpty(frame) ||
        (vertical && (frame.size.height < minimumFloatingHeight || frame.size.width < 44));
    self.tabBarContentInsets = managed;
    [self applyManagedInsets:managed toController:self.selectedViewController];
    self.updatingBarLayout = NO;
}

/// 外观复制后更新栏几何和内容避让，保持已有页面、按钮身份及导航栈。
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    for (UINavigationController *navigation in self.navigationDelegates) {
        XBTabNavigationDelegate *proxy = [self.navigationDelegates objectForKey:navigation];
        if (navigation.delegate == proxy) {
            navigation.delegate = proxy.originalDelegate;
        }
    }
    for (UIViewController *controller in self.managedInsets) {
        UIEdgeInsets managed = [[self.managedInsets objectForKey:controller] UIEdgeInsetsValue];
        UIEdgeInsets insets = controller.additionalSafeAreaInsets;
        insets.left -= managed.left;
        insets.right -= managed.right;
        insets.bottom -= managed.bottom;
        controller.additionalSafeAreaInsets = insets;
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
