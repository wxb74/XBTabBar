#import "XBDemoController.h"

@interface XBDemoController () <XBTabContainerDelegate>
@property (nonatomic, copy) NSArray<UINavigationController *> *pages;
@property (nonatomic, copy) NSArray<XBTabBarItem *> *pageItems;
@property (nonatomic) BOOL expanded;
@property (nonatomic) BOOL accessAllowed;
@property (nonatomic) NSUInteger layoutMode;
@property (nonatomic) NSUInteger badgeMode;
@property (nonatomic) NSUInteger selectionCount;
@property (nonatomic, copy) NSString *eventText;
- (void)performDemoAction:(NSUInteger)action;
@end

@interface XBDemoPage : UITableViewController
@property (nonatomic, weak) XBDemoController *demo;
@property (nonatomic) NSUInteger pageNumber;
@end

@implementation XBDemoController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.selectionDelegate = self;
    self.eventText = @"点击底栏可切页，再次点击会触发重复选择回调。";
    NSArray *titles = @[@"首页", @"发现", @"消息", @"收藏", @"工具", @"我的"];
    NSArray *symbols = @[@"house", @"safari", @"bubble.left.and.bubble.right", @"star", @"square.grid.2x2", @"person.crop.circle"];
    NSMutableArray *pages = [NSMutableArray array], *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < titles.count; i++) {
        XBDemoPage *page = [[XBDemoPage alloc] initWithStyle:UITableViewStyleInsetGrouped];
        page.title = titles[i]; page.demo = self; page.pageNumber = i;
        page.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"示例目录" style:UIBarButtonItemStylePlain target:self action:@selector(closeDemo)];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:page];
        navigation.navigationBar.prefersLargeTitles = YES;
        [pages addObject:navigation];
        XBTabBarItem *item = [[XBTabBarItem alloc] initWithIdentifier:[NSString stringWithFormat:@"page.%lu", (unsigned long)i] title:titles[i] image:[UIImage systemImageNamed:symbols[i]] selectedImage:[UIImage systemImageNamed:[symbols[i] stringByAppendingString:@".fill"]]];
        if (i == 2) item.badgeValue = @"8";
        [items addObject:item];
    }
    self.pages = pages; self.pageItems = items;
    XBTabBarAppearance *appearance = self.tabBarAppearance;
    appearance.selectedColor = UIColor.systemIndigoColor;
    appearance.selectionAnimationType = XBTabBarItemAnimationSpring;
    self.tabBarAppearance = appearance;
    [self rebuildTabs];
}
- (void)closeDemo { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)rebuildTabs {
    NSUInteger count = self.expanded ? 6 : 3;
    NSMutableArray *items = [NSMutableArray arrayWithArray:[self.pageItems subarrayWithRange:NSMakeRange(0, count)]];
    XBTabBarItem *action = [[XBTabBarItem alloc] initWithIdentifier:@"publish" title:@"发布" image:[UIImage systemImageNamed:@"plus"] selectedImage:nil kind:XBTabBarItemKindAction];
    XBTabBarItemStyle *style = self.tabBarAppearance;
    style.layout = XBTabBarItemLayoutImageOnly; style.buttonSize = CGSizeMake(56, 56);
    style.contentInsets = UIEdgeInsetsZero; style.raisedHeight = 12; style.cornerRadius = 28;
    style.normalBackgroundColor = UIColor.systemIndigoColor; style.normalColor = UIColor.whiteColor;
    action.style = style;
    [items insertObject:action atIndex:MIN(2, items.count)];
    [self setViewControllers:[self.pages subarrayWithRange:NSMakeRange(0, count)] tabBarItems:items];
}
- (void)reloadPages {
    for (UINavigationController *navigation in self.pages) {
        XBDemoPage *page = (id)navigation.viewControllers.firstObject;
        if (page.isViewLoaded) [page.tableView reloadData];
    }
}
- (BOOL)tabContainer:(XBTabContainerViewController *)container shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    if ([item.identifier isEqualToString:@"page.5"] && !self.accessAllowed) {
        self.eventText = @"准入已拒绝“我的”，当前页面与底栏高亮保持不变。";
        [self reloadPages];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"准入拦截示例" message:@"在任一页面打开“允许进入我的”，然后再次点击。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [self.selectedViewController presentViewController:alert animated:YES completion:nil];
        return NO;
    }
    return YES;
}
- (void)tabContainer:(XBTabContainerViewController *)container didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected {
    self.selectionCount++;
    self.eventText = [NSString stringWithFormat:@"%@：%@，回调累计 %lu 次", item.title, reselected ? @"重复点击" : @"切换页面", (unsigned long)self.selectionCount];
    [self reloadPages];
}
- (void)tabContainer:(XBTabContainerViewController *)container didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    self.eventText = @"已触发独立 Action，选中页面和导航栈保持原样。"; [self reloadPages];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"独立发布操作" message:@"这个按钮无需占位控制器，也不会成为选中页面。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:nil]];
    [self.selectedViewController presentViewController:alert animated:YES completion:nil];
}
- (void)performDemoAction:(NSUInteger)action {
    XBTabBarAppearance *appearance = self.tabBarAppearance;
    switch (action) {
        case 0: self.expanded = !self.expanded; [self rebuildTabs]; break;
        case 1: {
            self.layoutMode = (self.layoutMode + 1) % 6;
            appearance.layout = (XBTabBarItemLayout)self.layoutMode; self.tabBarAppearance = appearance; break;
        }
        case 2: {
            self.badgeMode = (self.badgeMode + 1) % 3;
            XBTabBarItem *message = self.pageItems[2];
            message.badgeValue = self.badgeMode == 0 ? @"8" : self.badgeMode == 1 ? @"" : nil;
            [self.tabBar updateItem:message]; break;
        }
        case 3:
            appearance.backgroundBlurEffect = appearance.backgroundBlurEffect ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
            self.tabBarAppearance = appearance; break;
        case 4:
            self.tabBar.semanticContentAttribute = self.tabBar.semanticContentAttribute == UISemanticContentAttributeForceRightToLeft ? UISemanticContentAttributeForceLeftToRight : UISemanticContentAttributeForceRightToLeft; break;
        case 5: self.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle == UIUserInterfaceStyleDark ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark; break;
        case 6: self.accessAllowed = !self.accessAllowed; break;
        case 7: {
            UIViewController *detail = [UIViewController new]; detail.title = @"导航详情";
            detail.view.backgroundColor = UIColor.systemGroupedBackgroundColor; detail.hidesBottomBarWhenPushed = YES;
            UILabel *label = [UILabel new]; label.translatesAutoresizingMaskIntoConstraints = NO;
            label.text = @"底栏已隐藏\n右滑返回，完成或取消均应正确恢复。"; label.numberOfLines = 0; label.textAlignment = NSTextAlignmentCenter;
            [detail.view addSubview:label];
            [NSLayoutConstraint activateConstraints:@[[label.centerXAnchor constraintEqualToAnchor:detail.view.centerXAnchor], [label.centerYAnchor constraintEqualToAnchor:detail.view.centerYAnchor], [label.widthAnchor constraintLessThanOrEqualToAnchor:detail.view.widthAnchor multiplier:0.85]]];
            [self.currentNavigationController pushViewController:detail animated:YES]; break;
        }
        case 8: {
            NSMutableArray *controllers = [self.viewControllers mutableCopy];
            NSMutableArray *items = [self.tabBar.items mutableCopy];
            // 只交换前两个页面；后面的 Action 槽位保持不变。
            [controllers exchangeObjectAtIndex:0 withObjectAtIndex:1]; [items exchangeObjectAtIndex:0 withObjectAtIndex:1];
            [self setViewControllers:controllers tabBarItems:items];
            self.eventText = @"前两个入口已重排，当前页面按 identifier 保留。"; break;
        }
        case 9: {
            XBTabBarItem *item = [self.tabBar itemForIdentifier:@"page.1"];
            item.enabled = !item.enabled; [self.tabBar updateItem:item];
            for (XBTabBarItem *config in self.pageItems) if ([config.identifier isEqualToString:item.identifier]) config.enabled = item.enabled;
            break;
        }
        case 10: {
            appearance.selectionAnimationType = (appearance.selectionAnimationType + 1) % 4;
            self.tabBarAppearance = appearance; break;
        }
        case 11: [self selectTabWithIdentifier:@"page.2"]; break;
    }
    [self reloadPages];
}
@end

@implementation XBDemoPage
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"demo.controls"; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 1 : section == 1 ? 7 : 5; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"XBTabBar · 0.1.0", @"外观与入口", @"交互与导航"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 2 ? @"iOS 15+ · Objective-C / Swift · UIKit + Masonry\n每个入口保留独立导航栈；设置均仅作用于本 Demo。" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0;
    if (indexPath.section == 0) {
        cell.textLabel.text = self.demo.eventText;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"当前页面：%@ · 页面下标 %lu · 按钮下标 %lu", self.title, (unsigned long)self.demo.selectedIndex, (unsigned long)self.demo.tabBar.selectedIndex];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        NSUInteger action = indexPath.section == 1 ? indexPath.row : indexPath.row + 7;
        NSArray *titles = @[@"切换 4 / 7 个入口", @"切换六种图文排列", @"切换数字 / 红点 / 隐藏", @"切换普通毛玻璃", @"切换从右向左布局（RTL）", @"切换浅色 / 深色", @"允许进入“我的”", @"Push 详情并隐藏底栏", @"重排前两个入口", @"禁用 / 启用发现入口", @"切换四种点击动画", @"按标识跳转消息页"];
        cell.textLabel.text = titles[action]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (action == 0) cell.detailTextLabel.text = self.demo.expanded ? @"当前：6 个页面 + 1 个 Action" : @"当前：3 个页面 + 1 个 Action";
        if (action == 1) cell.detailTextLabel.text = @[@"上图下文", @"上文下图", @"图在前", @"文在前", @"仅图标", @"仅标题"][self.demo.layoutMode];
        if (action == 6) cell.detailTextLabel.text = self.demo.accessAllowed ? @"已允许；7 入口模式下可直接进入" : @"未允许；点击“我的”将被拦截";
        if (action == 10) cell.detailTextLabel.text = @[@"关闭", @"缩放", @"弹簧", @"轻跳"][self.demo.tabBarAppearance.selectionAnimationType];
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section > 0) [self.demo performDemoAction:indexPath.section == 1 ? indexPath.row : indexPath.row + 7];
}
@end
