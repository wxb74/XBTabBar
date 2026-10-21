#import "XBShowcaseController.h"

static NSArray<XBTabBarItem *> *XBEmbeddedItems(void) {
    NSMutableArray *items = [NSMutableArray array];
    NSArray *titles = @[@"首页", @"发现", @"我的"], *icons = @[@"house", @"safari", @"person"];
    for (NSUInteger i = 0; i < 3; i++) [items addObject:[[XBTabBarItem alloc] initWithIdentifier:titles[i] title:titles[i] image:[UIImage systemImageNamed:icons[i]] selectedImage:nil]];
    return items;
}

@interface XBStandaloneController : UITableViewController
@property (nonatomic, strong) XBTabBarView *bar;
@property (nonatomic, strong) UILabel *eventLabel;
@property (nonatomic) BOOL rejects;
@property (nonatomic) NSUInteger badgeStep;
@end
@implementation XBStandaloneController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"独立按钮栏";
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 185)];
    self.eventLabel = [UILabel new]; self.eventLabel.numberOfLines = 0; self.eventLabel.textAlignment = NSTextAlignmentCenter; self.eventLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.eventLabel.text = @"这里只嵌入 XBTabBarView\n点击由当前页面处理，不切换控制器。";
    self.bar = [XBTabBarView new];
    XBTabBarAppearance *appearance = self.bar.appearance; appearance.selectedColor = UIColor.systemTealColor; appearance.selectionAnimationType = XBTabBarItemAnimationSpring; self.bar.appearance = appearance;
    NSMutableArray *items = [XBEmbeddedItems() mutableCopy];
    [items insertObject:[[XBTabBarItem alloc] initWithIdentifier:@"action" title:@"操作" image:[UIImage systemImageNamed:@"plus.circle"] selectedImage:nil kind:XBTabBarItemKindAction] atIndex:2];
    [self.bar setItems:items];
    __weak typeof(self) weakSelf = self;
    self.bar.itemTapHandler = ^(NSString *identifier, NSUInteger index) {
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        if (strongSelf.rejects && [identifier isEqualToString:@"发现"]) { strongSelf.eventLabel.text = @"发现入口被拒绝\n没有改变选择或播放动画。"; return; }
        BOOL reselected = strongSelf.bar.selectedIndex == index;
        XBTabBarItem *item = strongSelf.bar.items[index];
        if (item.kind == XBTabBarItemKindPage) strongSelf.bar.selectedIndex = index;
        [strongSelf.bar animateSelectionAtIndex:index reselected:reselected];
        strongSelf.eventLabel.text = [NSString stringWithFormat:@"外部已接收：%@\n%@，当前按钮下标 %lu", identifier, item.kind == XBTabBarItemKindAction ? @"独立操作" : reselected ? @"重复点击" : @"普通选择", (unsigned long)strongSelf.bar.selectedIndex];
    };
    for (UIView *view in @[self.eventLabel, self.bar]) { view.translatesAutoresizingMaskIntoConstraints = NO; [header addSubview:view]; }
    [NSLayoutConstraint activateConstraints:@[[self.eventLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:12], [self.eventLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20], [self.eventLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20], [self.bar.topAnchor constraintEqualToAnchor:self.eventLabel.bottomAnchor constant:18], [self.bar.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16], [self.bar.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16], [self.bar.heightAnchor constraintEqualToConstant:64]]];
    self.tableView.tableHeaderView = header;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 4; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = @[@"切换发现入口的准入拦截", @"切换我的入口的数字 / 红点 / 隐藏", @"禁用 / 启用我的入口", @"隐藏 / 显示整个按钮栏"][path.row]; cell.textLabel.numberOfLines = 0; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.row == 0) { self.rejects = !self.rejects; self.eventLabel.text = self.rejects ? @"发现入口准入拦截已开启。" : @"发现入口准入拦截已关闭。"; }
    if (path.row == 1) { self.badgeStep++; [self.bar setBadgeValue:self.badgeStep % 3 == 1 ? @"8" : self.badgeStep % 3 == 2 ? @"" : nil forIdentifier:@"我的"]; }
    if (path.row == 2) { XBTabBarItem *item = [self.bar itemForIdentifier:@"我的"]; item.enabled = !item.enabled; [self.bar updateItem:item]; }
    if (path.row == 3) self.bar.hidden = !self.bar.hidden;
}
@end
UIViewController *XBMakeStandaloneExample(void) { return [[XBStandaloneController alloc] initWithStyle:UITableViewStyleInsetGrouped]; }

@interface XBMultipleController : UIViewController
@property (nonatomic, copy) NSArray<XBTabContainerViewController *> *containers;
@end
@implementation XBMultipleController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"两个独立容器"; self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    NSMutableArray *containers = [NSMutableArray array];
    UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 16; stack.distribution = UIStackViewDistributionFillEqually; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12], [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12], [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16], [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16]]];
    for (NSUInteger i = 0; i < 2; i++) {
        UIView *panel = [UIView new]; panel.layer.cornerRadius = 16; panel.clipsToBounds = YES; [stack addArrangedSubview:panel];
        XBTabContainerViewController *tabs = [XBTabContainerViewController new];
        NSMutableArray *pages = [NSMutableArray array];
        for (XBTabBarItem *item in XBEmbeddedItems()) {
            UIViewController *page = [UIViewController new]; page.view.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            UILabel *label = [UILabel new]; label.translatesAutoresizingMaskIntoConstraints = NO; label.textAlignment = NSTextAlignmentCenter; label.numberOfLines = 0;
            label.text = [NSString stringWithFormat:@"%@容器 · %@\n点击各自底栏，观察另一个容器保持原状。", i == 0 ? @"上方" : @"下方", item.title];
            [page.view addSubview:label];
            [NSLayoutConstraint activateConstraints:@[[label.leadingAnchor constraintEqualToAnchor:page.view.leadingAnchor constant:12], [label.trailingAnchor constraintEqualToAnchor:page.view.trailingAnchor constant:-12], [label.centerYAnchor constraintEqualToAnchor:page.view.safeAreaLayoutGuide.centerYAnchor]]];
            [pages addObject:page];
        }
        [tabs setViewControllers:pages tabBarItems:XBEmbeddedItems()];
        XBTabBarAppearance *appearance = tabs.tabBarAppearance; appearance.selectedColor = i == 0 ? UIColor.systemIndigoColor : UIColor.systemOrangeColor; appearance.layout = i == 0 ? XBTabBarItemLayoutImageAboveTitle : XBTabBarItemLayoutImageLeading; tabs.tabBarAppearance = appearance; tabs.selectedIndex = i;
        [self addChildViewController:tabs]; tabs.view.translatesAutoresizingMaskIntoConstraints = NO; [panel addSubview:tabs.view];
        [NSLayoutConstraint activateConstraints:@[[tabs.view.topAnchor constraintEqualToAnchor:panel.topAnchor], [tabs.view.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor], [tabs.view.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor], [tabs.view.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor]]];
        [tabs didMoveToParentViewController:self]; [containers addObject:tabs];
    }
    self.containers = containers;
}
@end
UIViewController *XBMakeMultipleContainersExample(void) { return [XBMultipleController new]; }

/// 不通过业务项目创建：在 Swift 源文件中实际构造公开组件。
@interface XBSwiftExampleFactory : NSObject
+ (XBTabContainerViewController *)makeExample;
@end

@interface XBInitializationController : UITableViewController
@end
@implementation XBInitializationController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"解码与 Swift 接入"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 2; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = path.row == 0 ? @"打开解码创建的容器与按钮栏" : @"打开 Swift 创建的容器";
    cell.detailTextLabel.text = path.row == 0 ? @"通过 initWithCoder: 创建后重新配置入口" : @"由 Swift 工厂创建，再由 Objective-C 展示";
    cell.detailTextLabel.numberOfLines = 0; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (id)decodeObject:(id)object asClass:(Class)target {
    NSError *error = nil; NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:&error];
    if (data == nil) return nil;
    NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error]; decoder.requiresSecureCoding = NO;
    [decoder setClass:target forClassName:NSStringFromClass([object class])];
    id result = [decoder decodeObjectForKey:NSKeyedArchiveRootObjectKey]; [decoder finishDecoding]; return result;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    XBTabContainerViewController *tabs;
    if (path.row == 0) {
        tabs = [self decodeObject:[UIViewController new] asClass:XBTabContainerViewController.class];
        UIViewController *page = [UIViewController new]; page.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
        XBTabBarView *bar = [self decodeObject:[UIView new] asClass:XBTabBarView.class]; [bar setItems:XBEmbeddedItems()];
        UILabel *label = [UILabel new]; label.text = @"容器和页面中的独立按钮栏\n均经过 initWithCoder: 初始化。"; label.numberOfLines = 0; label.textAlignment = NSTextAlignmentCenter;
        for (UIView *view in @[label, bar]) { view.translatesAutoresizingMaskIntoConstraints = NO; [page.view addSubview:view]; }
        [NSLayoutConstraint activateConstraints:@[[label.centerXAnchor constraintEqualToAnchor:page.view.centerXAnchor], [label.centerYAnchor constraintEqualToAnchor:page.view.centerYAnchor constant:-60], [bar.leadingAnchor constraintEqualToAnchor:page.view.leadingAnchor constant:16], [bar.trailingAnchor constraintEqualToAnchor:page.view.trailingAnchor constant:-16], [bar.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:30], [bar.heightAnchor constraintEqualToConstant:64]]];
        __weak XBTabBarView *weakBar = bar; bar.itemTapHandler = ^(NSString *identifier, NSUInteger index) { weakBar.selectedIndex = index; };
        page.title = @"解码创建成功"; tabs.viewControllers = @[[[UINavigationController alloc] initWithRootViewController:page]];
    } else tabs = [XBSwiftExampleFactory makeExample];
    if (tabs == nil) return;
    for (UINavigationController *navigation in tabs.viewControllers) {
        navigation.viewControllers.firstObject.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回接入示例" style:UIBarButtonItemStylePlain target:self action:@selector(closeExample)];
    }
    tabs.modalPresentationStyle = UIModalPresentationFullScreen; [self presentViewController:tabs animated:YES completion:nil];
}
- (void)closeExample { [self dismissViewControllerAnimated:YES completion:nil]; }
@end
UIViewController *XBMakeInitializationExample(void) { return [[XBInitializationController alloc] initWithStyle:UITableViewStyleInsetGrouped]; }
