#import "XBCatalogController.h"
#import "XBShowcaseController.h"
#import "XBDemoController.h"

@implementation XBCatalogController
+ (NSArray<NSDictionary *> *)exampleSections {
    return @[
        @{@"title":@"基础样式", @"rows":@[
            @{@"id":@"classic", @"title":@"经典五入口", @"detail":@"标准图文底栏 · 普通与选中状态", @"symbol":@"square.grid.2x2"},
            @{@"id":@"seven", @"title":@"七入口与独立操作", @"detail":@"6 个页面 + 1 个 Action · 全部直接展示", @"symbol":@"rectangle.split.3x1"},
            @{@"id":@"layouts", @"title":@"六种图文排列", @"detail":@"上下 / 横向 / 纯图 / 纯文 · 缺图文回退", @"symbol":@"text.below.photo"},
            @{@"id":@"raised", @"title":@"多个凸起与不同形状", @"detail":@"圆形 / 圆角矩形 · 任意位置 · 页面或操作", @"symbol":@"plus.circle"}]},
        @{@"title":@"外观定制", @"rows":@[
            @{@"id":@"background", @"title":@"背景与栏高度", @"detail":@"背景图片 / 毛玻璃 / 遮罩 / 分割线", @"symbol":@"paintpalette"},
            @{@"id":@"typography", @"title":@"字体、图标与间距", @"detail":@"字体 / 选中字体 / 图标尺寸 / 内容边距", @"symbol":@"textformat.size"},
            @{@"id":@"itemStyle", @"title":@"单项独立样式", @"detail":@"独立背景图与选中背景 · 恢复全局继承", @"symbol":@"slider.horizontal.3"},
            @{@"id":@"badges", @"title":@"角标完整示例", @"detail":@"数字 / 红点 / 文本 / 自定义颜色 / 凸起角标", @"symbol":@"app.badge"},
            @{@"id":@"animations", @"title":@"预设与自定义动画", @"detail":@"全局预设 / 单项覆盖 / 自定义图标动画", @"symbol":@"sparkles"}]},
        @{@"title":@"交互与容器", @"rows":@[
            @{@"id":@"updates", @"title":@"动态文案与图片", @"detail":@"更新标题 / 图片 / 选中图片 / 禁用状态", @"symbol":@"arrow.triangle.2.circlepath"},
            @{@"id":@"selection", @"title":@"选择、拦截与静默定位", @"detail":@"准入拒绝 / 重复点击 / 不触发回调的定位", @"symbol":@"hand.tap"},
            @{@"id":@"structure", @"title":@"入口增删与重建", @"detail":@"重排 / 新控制器恢复 / 空配置 / 纯 Action", @"symbol":@"rectangle.3.group"},
            @{@"id":@"navigation", @"title":@"导航栈与底栏隐藏", @"detail":@"独立导航栈 · Push / Pop · 侧滑返回", @"symbol":@"arrow.triangle.branch"},
            @{@"id":@"standalone", @"title":@"独立使用 XBTabBarView", @"detail":@"在页面中嵌入按钮栏，由外部处理选择", @"symbol":@"rectangle.bottomthird.inset.filled"},
            @{@"id":@"multiple", @"title":@"多个容器独立运行", @"detail":@"上下两个容器 · 选中状态与外观互不影响", @"symbol":@"rectangle.split.1x2"}]},
        @{@"title":@"适配与接入", @"rows":@[
            @{@"id":@"accessibility", @"title":@"布局方向与辅助功能", @"detail":@"从右向左布局（RTL） / 深浅色 / 系统偏好", @"symbol":@"accessibility"},
            @{@"id":@"initialization", @"title":@"解码初始化与 Swift 接入", @"detail":@"实际解码创建 / 实际 Swift 创建后打开", @"symbol":@"curlybraces"},
            @{@"id":@"all", @"title":@"综合交互面板", @"detail":@"保留原版 Demo 的全部快捷控制项", @"symbol":@"switch.2"}]}];
}
+ (UIViewController *)exampleWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"standalone"]) return XBMakeStandaloneExample();
    if ([identifier isEqualToString:@"multiple"]) return XBMakeMultipleContainersExample();
    if ([identifier isEqualToString:@"initialization"]) return XBMakeInitializationExample();
    if ([identifier isEqualToString:@"all"]) return [XBDemoController new];
    return [[XBShowcaseController alloc] initWithExampleIdentifier:identifier];
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"XBTabBar 示例";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.tableView.accessibilityIdentifier = @"demo.catalog";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 78;
    self.navigationItem.backButtonTitle = @"示例目录";
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.class.exampleSections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.class.exampleSections[section][@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.class.exampleSections[section][@"title"]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"点击进入独立示例，每个页面都有对应的操作项。" : section == 3 ? @"组件 0.1.0 · Demo 0.2.0 · UIKit + Masonry · iOS 15+" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *entry = self.class.exampleSections[indexPath.section][@"rows"][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = entry[@"title"];
    cell.detailTextLabel.text = entry[@"detail"];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.textLabel.adjustsFontForContentSizeCategory = YES; cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0; cell.detailTextLabel.numberOfLines = 0;
    cell.imageView.image = [UIImage systemImageNamed:entry[@"symbol"]];
    cell.imageView.tintColor = @[UIColor.systemIndigoColor, UIColor.systemOrangeColor, UIColor.systemTealColor, UIColor.systemPurpleColor][indexPath.section];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessibilityIdentifier = [@"catalog." stringByAppendingString:entry[@"id"]];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *entry = self.class.exampleSections[indexPath.section][@"rows"][indexPath.row];
    UIViewController *example = [self.class exampleWithIdentifier:entry[@"id"]];
    example.title = entry[@"title"];
    if ([example isKindOfClass:XBTabContainerViewController.class]) {
        example.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:example animated:YES completion:nil];
    } else {
        [self.navigationController pushViewController:example animated:YES];
    }
}
@end
