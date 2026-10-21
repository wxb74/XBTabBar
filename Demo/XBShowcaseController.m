#import "XBShowcaseController.h"
#import <QuartzCore/QuartzCore.h>

static NSDictionary *XBControl(NSString *title, NSString *action) { return @{@"title":title, @"action":action}; }

/// 使用本地绘制图片展示背景接口，不依赖远程资源。
static UIImage *XBBackgroundImage(UIColor *first, UIColor *second) {
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(320, 90)] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [first setFill]; UIRectFill(CGRectMake(0, 0, 320, 90));
        [second setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(70, -80, 320, 220)] fill];
    }];
}

@interface XBShowcaseController () <XBTabContainerDelegate>
@property (nonatomic, copy) NSString *exampleIdentifier;
@property (nonatomic, copy) NSArray<UINavigationController *> *pages;
@property (nonatomic, strong) NSMutableArray<XBTabBarItem *> *pageItems;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *steps;
@property (nonatomic, copy) NSString *eventText;
@property (nonatomic) NSUInteger selectionCallbacks;
@property (nonatomic) BOOL allowed;
@property (nonatomic, strong) UIStackView *emptyPanel;
@property (nonatomic, strong) UILabel *emptyLabel;
- (NSArray<NSDictionary *> *)controls;
- (void)performAction:(NSString *)action;
- (void)reloadPages;
- (void)exitExample;
@end

@interface XBShowcasePage : UITableViewController
@property (nonatomic, weak) XBShowcaseController *owner;
@property (nonatomic) NSUInteger appearances;
@property (nonatomic) NSUInteger disappearances;
@end

@implementation XBShowcaseController
- (instancetype)initWithExampleIdentifier:(NSString *)identifier {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _exampleIdentifier = [identifier copy]; _steps = [NSMutableDictionary dictionary];
        _eventText = @"点击下方操作或底栏入口，观察当前示例的变化。";
    }
    return self;
}
- (BOOL)isExample:(NSString *)key { return [self.exampleIdentifier isEqualToString:key]; }
- (NSUInteger)nextStep:(NSString *)key {
    NSUInteger step = [self.steps[key] unsignedIntegerValue] + 1; self.steps[key] = @(step); return step;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor; self.selectionDelegate = self;
    [self makePages];
    XBTabBarAppearance *appearance = self.tabBarAppearance;
    appearance.selectedColor = UIColor.systemIndigoColor;
    appearance.selectionAnimationType = XBTabBarItemAnimationScale;
    if ([self isExample:@"typography"]) { appearance.contentHeight = 64; appearance.titleFont = [UIFont systemFontOfSize:13]; appearance.selectedTitleFont = [UIFont boldSystemFontOfSize:15]; }
    if ([self isExample:@"background"]) { appearance.backgroundImage = XBBackgroundImage([UIColor.systemIndigoColor colorWithAlphaComponent:0.15], [UIColor.systemTealColor colorWithAlphaComponent:0.2]); }
    if ([self isExample:@"layouts"]) { appearance.layout = XBTabBarItemLayoutImageLeading; _steps[@"layout"] = @2; }
    self.tabBarAppearance = appearance;
    [self configurePageCount:[self isExample:@"classic"] ? 5 : [self isExample:@"seven"] ? 6 : 3];
    if ([self isExample:@"itemStyle"]) [self applyDistinctStyle];
    if ([self isExample:@"animations"]) [self applyPerItemAnimations];
    if ([self isExample:@"badges"]) [self applyBadges:0];
}
- (void)makePages {
    NSArray *titles = @[@"首页", @"发现", @"消息", @"收藏", @"工具", @"我的"];
    NSArray *symbols = @[@"house", @"safari", @"bubble.left.and.bubble.right", @"star", @"square.grid.2x2", @"person.crop.circle"];
    NSMutableArray *controllers = [NSMutableArray array]; self.pageItems = [NSMutableArray array];
    for (NSUInteger i = 0; i < 6; i++) {
        XBShowcasePage *page = [[XBShowcasePage alloc] initWithStyle:UITableViewStyleInsetGrouped];
        page.title = titles[i]; page.owner = self;
        page.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"示例目录" style:UIBarButtonItemStylePlain target:self action:@selector(exitExample)];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:page];
        navigation.navigationBar.prefersLargeTitles = YES; [controllers addObject:navigation];
        [self.pageItems addObject:[[XBTabBarItem alloc] initWithIdentifier:[NSString stringWithFormat:@"page.%lu", (unsigned long)i] title:titles[i] image:[UIImage systemImageNamed:symbols[i]] selectedImage:[UIImage systemImageNamed:[symbols[i] stringByAppendingString:@".fill"]]]];
    }
    self.pages = controllers;
}
- (XBTabBarItem *)actionItem:(NSString *)identifier rounded:(BOOL)rounded {
    XBTabBarItem *item = [[XBTabBarItem alloc] initWithIdentifier:identifier title:([identifier isEqualToString:@"action.second"] ? @"编辑" : @"发布") image:[UIImage systemImageNamed:[identifier isEqualToString:@"action.second"] ? @"pencil" : @"plus"] selectedImage:nil kind:XBTabBarItemKindAction];
    XBTabBarItemStyle *style = self.tabBarAppearance;
    style.layout = XBTabBarItemLayoutImageOnly; style.buttonSize = CGSizeMake(52, 52);
    style.contentInsets = UIEdgeInsetsZero; style.raisedHeight = 10; style.cornerRadius = rounded ? 14 : 26;
    style.normalBackgroundColor = rounded ? UIColor.systemOrangeColor : UIColor.systemIndigoColor;
    style.normalColor = UIColor.whiteColor; item.style = style;
    if ([self isExample:@"badges"]) item.badgeValue = @"6";
    return item;
}
- (void)configurePageCount:(NSUInteger)count {
    NSMutableArray<XBTabBarItem *> *items = [[self.pageItems subarrayWithRange:NSMakeRange(0, count)] mutableCopy];
    if ([self isExample:@"seven"] || [self isExample:@"badges"] || [self isExample:@"raised"]) {
        NSUInteger position = MIN([self.steps[@"position"] unsignedIntegerValue] % (items.count + 1), items.count);
        if (self.steps[@"position"] == nil) position = MIN(2, items.count);
        BOOL rounded = [self.steps[@"shape"] unsignedIntegerValue] % 2 == 1;
        [items insertObject:[self actionItem:@"action.first" rounded:rounded] atIndex:position];
        if ([self isExample:@"raised"]) {
            [items addObject:[self actionItem:@"action.second" rounded:!rounded]];
            XBTabBarItem *page = [self.pageItems[1] copy];
            XBTabBarItemStyle *style = self.tabBarAppearance; style.buttonSize = CGSizeMake(56, 62);
            style.raisedHeight = 8; style.cornerRadius = 16;
            style.normalBackgroundColor = [UIColor.systemTealColor colorWithAlphaComponent:0.15];
            style.selectedBackgroundColor = [UIColor.systemTealColor colorWithAlphaComponent:0.3];
            page.style = style;
            for (NSUInteger i = 0; i < items.count; i++) if ([items[i].identifier isEqualToString:page.identifier]) items[i] = page;
        }
    }
    [self setViewControllers:[self.pages subarrayWithRange:NSMakeRange(0, count)] tabBarItems:items];
    self.emptyPanel.hidden = count > 0;
}
- (void)updateItem:(XBTabBarItem *)item {
    [self.tabBar updateItem:item];
    for (NSUInteger i = 0; i < self.pageItems.count; i++) if ([self.pageItems[i].identifier isEqualToString:item.identifier]) self.pageItems[i] = [item copy];
}
- (void)applyDistinctStyle {
    XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.1"];
    XBTabBarItemStyle *style = self.tabBarAppearance;
    style.layout = XBTabBarItemLayoutImageLeading; style.titleFont = [UIFont boldSystemFontOfSize:12];
    style.normalColor = UIColor.systemOrangeColor; style.selectedColor = UIColor.systemPinkColor;
    style.normalBackgroundImage = XBBackgroundImage([UIColor.systemOrangeColor colorWithAlphaComponent:0.12], [UIColor.systemPinkColor colorWithAlphaComponent:0.15]);
    style.selectedBackgroundImage = XBBackgroundImage([UIColor.systemPinkColor colorWithAlphaComponent:0.3], [UIColor.systemOrangeColor colorWithAlphaComponent:0.3]);
    style.normalBackgroundColor = UIColor.clearColor; style.selectedBackgroundColor = UIColor.systemYellowColor;
    style.cornerRadius = 12; item.style = style; [self updateItem:item];
}
- (void)applyPerItemAnimations {
    for (NSUInteger i = 0; i < self.tabBar.items.count; i++) {
        XBTabBarItem *item = self.tabBar.items[i]; XBTabBarItemStyle *style = self.tabBarAppearance;
        style.selectionAnimationType = (XBTabBarItemAnimation)(i % 3 + 1); item.style = style; [self updateItem:item];
    }
}
- (void)applyBadges:(NSUInteger)mode {
    NSArray *values = @[@"8", @"", @"NEW", @"999999+"];
    for (NSUInteger i = 0; i < self.tabBar.items.count; i++) {
        XBTabBarItem *item = self.tabBar.items[i]; item.badgeValue = mode % 5 == 4 ? nil : values[(i + mode) % 4];
        [self updateItem:item];
    }
}
- (NSArray<NSDictionary *> *)controls {
    if ([self isExample:@"classic"]) return @[XBControl(@"切换普通 / 选中配色", @"colors"), XBControl(@"切换浅色 / 深色", @"theme")];
    if ([self isExample:@"seven"]) return @[XBControl(@"切换 4 / 7 个入口", @"count"), XBControl(@"移动独立 Action 的位置", @"position")];
    if ([self isExample:@"layouts"]) return @[XBControl(@"切换六种图文排列", @"layout"), XBControl(@"首页缺图 / 缺标题 / 恢复", @"missing"), XBControl(@"切换从右向左布局（RTL）", @"rtl")];
    if ([self isExample:@"raised"]) return @[XBControl(@"移动凸起 Action 的位置", @"position"), XBControl(@"切换圆形 / 圆角矩形", @"shape"), XBControl(@"调整按钮尺寸与抬升高度", @"raiseSize")];
    if ([self isExample:@"background"]) return @[XBControl(@"切换底栏背景图片", @"backgroundImage"), XBControl(@"切换普通毛玻璃", @"blur"), XBControl(@"切换调色遮罩", @"overlay"), XBControl(@"调整栏高：49 / 64 / 80", @"height"), XBControl(@"切换分割线颜色与高度", @"separator")];
    if ([self isExample:@"typography"]) return @[XBControl(@"调整普通与选中字体", @"font"), XBControl(@"调整图标尺寸：18 / 23 / 30", @"iconSize"), XBControl(@"调整图文间距", @"spacing"), XBControl(@"调整内容边距", @"insets"), XBControl(@"切换横排 / 竖排", @"horizontal")];
    if ([self isExample:@"itemStyle"]) return @[XBControl(@"切换发现入口的独立样式 / 继承全局", @"itemStyle"), XBControl(@"改变全局配色，观察独立样式", @"colors"), XBControl(@"切换单项背景图片 / 背景色", @"itemImage"), XBControl(@"切换发现入口选中状态", @"selectDiscovery")];
    if ([self isExample:@"badges"]) return @[XBControl(@"切换数字 / 红点 / 文本 / 长文本 / 隐藏", @"badges"), XBControl(@"自定义角标颜色与高度", @"badgeStyle"), XBControl(@"切换布局检查角标锚点", @"layout"), XBControl(@"切换从右向左布局（RTL）", @"rtl")];
    if ([self isExample:@"animations"]) return @[XBControl(@"切换全局预设并恢复所有入口继承", @"animation"), XBControl(@"各入口分别使用缩放 / 弹簧 / 轻跳", @"perItemAnimation"), XBControl(@"启用 / 关闭自定义旋转动画", @"customAnimation")];
    if ([self isExample:@"updates"]) return @[XBControl(@"更新首页标题", @"title"), XBControl(@"更新普通图片与选中图片", @"image"), XBControl(@"禁用 / 启用发现入口", @"enabled")];
    if ([self isExample:@"selection"]) return @[XBControl(@"允许 / 拦截消息入口", @"allow"), XBControl(@"按标识进入消息，触发准入与回调", @"selectMessage"), XBControl(@"按下标静默进入消息", @"silentIndex"), XBControl(@"按控制器对象静默进入首页", @"silentObject"), XBControl(@"再次选择当前页，触发重复点击", @"reselect")];
    if ([self isExample:@"structure"]) return @[XBControl(@"交换前两个入口，保留选中页面", @"reorder"), XBControl(@"增删尾部入口：3 / 5 个", @"count"), XBControl(@"替换为全新控制器，按标识恢复选择", @"rebuild"), XBControl(@"清空所有入口", @"empty"), XBControl(@"仅保留 Action 操作入口", @"actionsOnly")];
    if ([self isExample:@"navigation"]) return @[XBControl(@"Push 详情，保留底栏以切换导航栈", @"pushKeep"), XBControl(@"Push 详情并隐藏底栏", @"pushHide"), XBControl(@"显示 / 隐藏底栏", @"hideBar")];
    return @[XBControl(@"切换从右向左布局（RTL）", @"rtl"), XBControl(@"切换浅色 / 深色", @"theme"), XBControl(@"刷新系统辅助功能状态", @"preferences"), XBControl(@"启用 / 关闭毛玻璃，检查减少透明度", @"blur"), XBControl(@"切换点击动画，检查减少动态效果", @"animation")];
}
- (void)performAction:(NSString *)action {
    NSUInteger step = [self nextStep:action]; XBTabBarAppearance *appearance = self.tabBarAppearance;
    self.eventText = @"配置已更新，可点击底栏观察效果。";
    if ([action isEqualToString:@"colors"]) { appearance.selectedColor = step % 2 ? UIColor.systemPinkColor : UIColor.systemIndigoColor; appearance.normalColor = step % 2 ? UIColor.systemTealColor : UIColor.secondaryLabelColor; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"theme"]) self.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle == UIUserInterfaceStyleDark ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
    else if ([action isEqualToString:@"rtl"]) self.tabBar.semanticContentAttribute = self.tabBar.semanticContentAttribute == UISemanticContentAttributeForceRightToLeft ? UISemanticContentAttributeForceLeftToRight : UISemanticContentAttributeForceRightToLeft;
    else if ([action isEqualToString:@"count"]) [self configurePageCount:step % 2 ? ([self isExample:@"seven"] ? 3 : 5) : ([self isExample:@"seven"] ? 6 : 3)];
    else if ([action isEqualToString:@"position"] || [action isEqualToString:@"shape"]) [self configurePageCount:self.viewControllers.count];
    else if ([action isEqualToString:@"layout"]) { appearance.layout = (XBTabBarItemLayout)(step % 6); self.tabBarAppearance = appearance; if ([self isExample:@"badges"]) { for (XBTabBarItem *item in self.tabBar.items) if (item.style != nil) { XBTabBarItemStyle *style = item.style; style.layout = appearance.layout; item.style = style; [self updateItem:item]; } } self.eventText = @[@"上图下文", @"上文下图", @"图在前、文在后", @"文在前、图在后", @"仅图标", @"仅标题"][step % 6]; }
    else if ([action isEqualToString:@"missing"]) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.0"]; item.title = step % 3 == 2 ? @"" : @"首页"; item.image = step % 3 == 1 ? nil : [UIImage systemImageNamed:@"house"]; item.selectedImage = step % 3 == 1 ? nil : [UIImage systemImageNamed:@"house.fill"]; [self updateItem:item]; }
    else if ([action isEqualToString:@"raiseSize"]) { for (XBTabBarItem *item in self.tabBar.items) if (item.kind == XBTabBarItemKindAction) { XBTabBarItemStyle *style = item.style; CGFloat size = step % 2 ? 62 : 52; style.buttonSize = CGSizeMake(size, size); style.raisedHeight = step % 2 ? 18 : 10; style.cornerRadius = style.cornerRadius > 20 ? size / 2 : 14; item.style = style; [self updateItem:item]; } }
    else if ([action isEqualToString:@"backgroundImage"]) { appearance.backgroundImage = step % 2 ? nil : XBBackgroundImage([UIColor.systemIndigoColor colorWithAlphaComponent:0.15], [UIColor.systemTealColor colorWithAlphaComponent:0.2]); self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"blur"]) { appearance.backgroundBlurEffect = appearance.backgroundBlurEffect ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"overlay"]) { appearance.backgroundOverlayColor = step % 2 ? [UIColor.systemPinkColor colorWithAlphaComponent:0.16] : nil; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"height"]) { appearance.contentHeight = [@[@49, @64, @80][step % 3] doubleValue]; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"separator"]) { appearance.separatorHeight = [@[@0.5, @2, @0][step % 3] doubleValue]; appearance.separatorColor = UIColor.systemOrangeColor; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"font"]) { appearance.titleFont = [UIFont systemFontOfSize:step % 2 ? 11 : 13]; appearance.selectedTitleFont = [UIFont boldSystemFontOfSize:step % 2 ? 14 : 15]; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"iconSize"]) { CGFloat size = [@[@18, @23, @30][step % 3] doubleValue]; appearance.imageSize = CGSizeMake(size, size); self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"spacing"]) { appearance.imageTitleSpacing = step % 2 ? 2 : 10; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"insets"]) { appearance.contentInsets = step % 2 ? UIEdgeInsetsMake(10, 12, 4, 12) : UIEdgeInsetsMake(5, 5, 0, 5); self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"horizontal"]) { appearance.layout = step % 2 ? XBTabBarItemLayoutImageLeading : XBTabBarItemLayoutImageAboveTitle; self.tabBarAppearance = appearance; }
    else if ([action isEqualToString:@"itemStyle"]) { if (step % 2) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.1"]; item.style = nil; [self updateItem:item]; } else [self applyDistinctStyle]; }
    else if ([action isEqualToString:@"itemImage"]) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.1"]; XBTabBarItemStyle *style = item.style ?: self.tabBarAppearance; style.normalBackgroundImage = step % 2 ? nil : XBBackgroundImage([UIColor.systemOrangeColor colorWithAlphaComponent:0.15], [UIColor.systemPinkColor colorWithAlphaComponent:0.15]); style.selectedBackgroundImage = step % 2 ? nil : XBBackgroundImage([UIColor.systemPinkColor colorWithAlphaComponent:0.3], [UIColor.systemOrangeColor colorWithAlphaComponent:0.3]); style.normalBackgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.12]; style.selectedBackgroundColor = [UIColor.systemPinkColor colorWithAlphaComponent:0.25]; item.style = style; [self updateItem:item]; }
    else if ([action isEqualToString:@"selectDiscovery"]) self.selectedIndex = self.selectedIndex == 1 ? 0 : 1;
    else if ([action isEqualToString:@"badges"]) [self applyBadges:step];
    else if ([action isEqualToString:@"badgeStyle"]) { for (XBTabBarItem *item in self.tabBar.items) { XBTabBarItemStyle *style = item.style ?: self.tabBarAppearance; style.badgeColor = step % 2 ? UIColor.systemPurpleColor : UIColor.systemRedColor; style.badgeTextColor = step % 2 ? UIColor.systemYellowColor : UIColor.whiteColor; style.badgeHeight = step % 2 ? 21 : 15; item.style = style; [self updateItem:item]; } }
    else if ([action isEqualToString:@"animation"]) { self.tabBar.selectionAnimation = nil; appearance.selectionAnimationType = (XBTabBarItemAnimation)(step % 4); self.tabBarAppearance = appearance; for (XBTabBarItem *item in self.tabBar.items) { item.style = nil; [self updateItem:item]; } self.eventText = @[@"动画关闭", @"全局缩放动画", @"全局弹簧动画", @"全局轻跳动画"][step % 4]; }
    else if ([action isEqualToString:@"perItemAnimation"]) { self.tabBar.selectionAnimation = nil; [self applyPerItemAnimations]; self.eventText = @"首页缩放、发现弹簧、消息轻跳。"; }
    else if ([action isEqualToString:@"customAnimation"]) { self.tabBar.selectionAnimation = step % 2 ? ^(UIView *image, BOOL reselected) { CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"]; animation.values = @[@0, @(-0.35), @0.35, @0]; animation.duration = 0.35; [image.layer addAnimation:animation forKey:@"demo.rotation"]; } : nil; self.eventText = step % 2 ? @"自定义旋转动画已启用，点击入口体验。" : @"自定义动画已关闭，恢复预设。"; }
    else if ([action isEqualToString:@"title"]) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.0"]; item.title = step % 2 ? @"精选" : @"首页"; [self updateItem:item]; }
    else if ([action isEqualToString:@"image"]) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.0"]; item.image = [UIImage systemImageNamed:step % 2 ? @"heart" : @"house"]; item.selectedImage = [UIImage systemImageNamed:step % 2 ? @"heart.fill" : @"house.fill"]; [self updateItem:item]; }
    else if ([action isEqualToString:@"enabled"]) { XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.1"]; item.enabled = !item.enabled; [self updateItem:item]; }
    else if ([action isEqualToString:@"allow"]) { self.allowed = !self.allowed; self.eventText = self.allowed ? @"消息入口已允许。" : @"消息入口将被拦截。"; }
    else if ([action isEqualToString:@"selectMessage"]) [self selectTabWithIdentifier:@"page.2"];
    else if ([action isEqualToString:@"silentIndex"]) { self.selectedIndex = 2; self.eventText = @"已静默进入消息，未触发准入和选择回调。"; }
    else if ([action isEqualToString:@"silentObject"]) { self.selectedViewController = self.viewControllers.firstObject; self.eventText = @"已按控制器对象静默进入首页。"; }
    else if ([action isEqualToString:@"reselect"]) { NSUInteger index = self.tabBar.selectedIndex; if (index < self.tabBar.items.count) [self selectTabWithIdentifier:self.tabBar.items[index].identifier]; }
    else if ([action isEqualToString:@"reorder"]) { NSMutableArray *pages = [self.viewControllers mutableCopy], *items = [self.tabBar.items mutableCopy]; if (pages.count >= 2) { [pages exchangeObjectAtIndex:0 withObjectAtIndex:1]; [items exchangeObjectAtIndex:0 withObjectAtIndex:1]; [self setViewControllers:pages tabBarItems:items]; } self.eventText = @"入口已重排，当前页面按标识保留。"; }
    else if ([action isEqualToString:@"rebuild"]) { NSArray *items = self.tabBar.items; NSUInteger count = self.viewControllers.count; [self makePages]; [self setViewControllers:[self.pages subarrayWithRange:NSMakeRange(0, count)] tabBarItems:items]; self.eventText = @"已替换为全新控制器对象，按稳定标识保留选择。"; }
    else if ([action isEqualToString:@"empty"]) { [self setViewControllers:@[] tabBarItems:@[]]; [self showEmptyPanel:NO]; }
    else if ([action isEqualToString:@"actionsOnly"]) { [self setViewControllers:@[] tabBarItems:@[[self actionItem:@"action.first" rounded:NO], [self actionItem:@"action.second" rounded:YES]]]; [self showEmptyPanel:YES]; }
    else if ([action isEqualToString:@"restore"]) { [self configurePageCount:3]; self.eventText = @"已恢复三个页面入口。"; }
    else if ([action isEqualToString:@"pushKeep"] || [action isEqualToString:@"pushHide"]) { XBShowcasePage *detail = [[XBShowcasePage alloc] initWithStyle:UITableViewStyleInsetGrouped]; detail.owner = self; detail.title = [NSString stringWithFormat:@"详情 %lu", (unsigned long)self.currentNavigationController.viewControllers.count]; detail.hidesBottomBarWhenPushed = [action isEqualToString:@"pushHide"]; [self.currentNavigationController pushViewController:detail animated:YES]; }
    else if ([action isEqualToString:@"hideBar"]) [self setTabBarHidden:!self.isTabBarHidden animated:YES];
    else if ([action isEqualToString:@"preferences"]) { self.eventText = [NSString stringWithFormat:@"VoiceOver：%@\n减少动态效果：%@\n减少透明度：%@\n请在系统辅助功能设置中调整，再返回刷新。", UIAccessibilityIsVoiceOverRunning() ? @"开启" : @"关闭", UIAccessibilityIsReduceMotionEnabled() ? @"开启" : @"关闭", UIAccessibilityIsReduceTransparencyEnabled() ? @"开启" : @"关闭"]; }
    [self reloadPages];
}
- (void)showEmptyPanel:(BOOL)actions {
    if (self.emptyPanel == nil) {
        self.emptyLabel = [UILabel new]; self.emptyLabel.numberOfLines = 0; self.emptyLabel.textAlignment = NSTextAlignmentCenter;
        UIButton *restore = [UIButton buttonWithType:UIButtonTypeSystem]; [restore setTitle:@"恢复三个页面入口" forState:UIControlStateNormal]; [restore addTarget:self action:@selector(restorePages) forControlEvents:UIControlEventTouchUpInside];
        UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem]; [back setTitle:@"返回示例目录" forState:UIControlStateNormal]; [back addTarget:self action:@selector(exitExample) forControlEvents:UIControlEventTouchUpInside];
        self.emptyPanel = [[UIStackView alloc] initWithArrangedSubviews:@[self.emptyLabel, restore, back]]; self.emptyPanel.axis = UILayoutConstraintAxisVertical; self.emptyPanel.spacing = 20; self.emptyPanel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.emptyPanel];
        [NSLayoutConstraint activateConstraints:@[[self.emptyPanel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor], [self.emptyPanel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor], [self.emptyPanel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor multiplier:0.85]]];
    }
    self.emptyPanel.hidden = NO;
    self.emptyLabel.text = actions ? @"纯 Action 配置\n没有占位控制器，点击下方操作不会产生选中页。" : @"空配置\n没有页面和按钮，可随时恢复。";
}
- (void)restorePages { [self performAction:@"restore"]; }
- (BOOL)tabContainer:(XBTabContainerViewController *)container shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    if ([self isExample:@"selection"] && [item.identifier isEqualToString:@"page.2"] && !self.allowed) { self.eventText = @"准入拒绝：消息入口未开放，页面与高亮保持原样。"; [self reloadPages]; return NO; }
    return YES;
}
- (void)tabContainer:(XBTabContainerViewController *)container didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected {
    self.selectionCallbacks++; self.eventText = [NSString stringWithFormat:@"%@：%@，选择回调累计 %lu 次。", item.title, reselected ? @"重复点击" : @"切换页面", (unsigned long)self.selectionCallbacks]; [self reloadPages];
}
- (void)tabContainer:(XBTabContainerViewController *)container didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    self.eventText = [NSString stringWithFormat:@"已触发“%@”独立操作，选中页保持不变。", item.title];
    if (self.viewControllers.count == 0) self.emptyLabel.text = self.eventText;
    [self reloadPages];
}
- (void)reloadPages {
    for (UINavigationController *navigation in self.pages) for (UIViewController *controller in navigation.viewControllers) if ([controller isKindOfClass:XBShowcasePage.class] && controller.isViewLoaded) [((XBShowcasePage *)controller).tableView reloadData];
}
- (void)exitExample { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

@implementation XBShowcasePage
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"showcase.controls"; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; self.appearances++; [self.tableView reloadData]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; self.disappearances++; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 1 : section == 1 ? self.owner.controls.count : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? self.owner.title ?: @"XBTabBar 示例" : section == 1 ? @"操作与观察" : @"返回"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { if (section != 1) return nil;
    if ([self.owner.exampleIdentifier isEqualToString:@"accessibility"]) return @"在系统设置调整辅助功能偏好，返回此页刷新状态。";
    if ([self.owner.exampleIdentifier isEqualToString:@"navigation"]) return @"保留底栏的详情页可跨入口切换，观察各自的导航层级。";
    if ([self.owner.exampleIdentifier isEqualToString:@"itemStyle"]) return @"单项样式是完整快照；恢复继承后跟随全局外观更新。";
    return nil; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0;
    if (path.section == 0) {
        cell.textLabel.text = self.owner.eventText;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"页面下标：%lu · 按钮下标：%lu\n栏高：%.0f · 当前页出现 %lu 次 / 消失 %lu 次\n导航栈深度：%lu · 选择回调：%lu 次", (unsigned long)self.owner.selectedIndex, (unsigned long)self.owner.tabBar.selectedIndex, self.owner.tabBarAppearance.contentHeight, (unsigned long)self.appearances, (unsigned long)self.disappearances, (unsigned long)self.navigationController.viewControllers.count, (unsigned long)self.owner.selectionCallbacks]; cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (path.section == 1) { NSDictionary *control = self.owner.controls[path.row]; cell.textLabel.text = control[@"title"]; cell.accessibilityIdentifier = [@"control." stringByAppendingString:control[@"action"]]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    else { cell.textLabel.text = @"返回示例目录"; cell.textLabel.textColor = UIColor.systemIndigoColor; }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 1) [self.owner performAction:self.owner.controls[path.row][@"action"]];
    if (path.section == 2) [self.owner exitExample];
}
@end
