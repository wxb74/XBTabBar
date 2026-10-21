# XBTabBar

Objective-C 多入口组件，版本 `0.1.0`，最低 iOS 15，仅依赖 UIKit、Masonry。
复制本目录六个 `.h/.m` 文件即可使用，不依赖本项目 PCH、主题、权限、网络或其它 TabBar SDK。

## 职责和取舍

- 借鉴 AxcAE_TabBar 的显式图文配置，以及 CYLTabBarController 的展示/业务分离、角标、点击动画扩展思路，独立实现，不复制第三方源码。
- `XBTabContainerViewController` 是 UIViewController 容器，每个入口保留自己的导航栈，6～7 个入口全部直显，不经过系统 More。
- `XBTabBarView` 只显示按钮；`XBTabBarItem` 是入口配置；`XBTabBarItemStyle` 是按钮完整样式，`XBTabBarAppearance` 在其基础上增加栏高与栏背景。
- 不使用 UIKit 私有视图、Swizzle、全局单例，不强制系统栏方向；动画默认关闭，不依赖 Lottie。
- 权限、登录、列表刷新、未读数字上限均在业务层。支持普通毛玻璃，不是系统 Liquid Glass；凸起布局与独立操作均可选，默认不启用。

## 当前已实现的能力

- 多入口全部直显，不生成系统 More；各入口保留独立导航栈，多个容器互不共享选中状态。
- 控制器与入口配置一起替换；标识唯一性检查、重排/重建后按标识恢复选择、空配置清理；独立操作不需要占位控制器。
- 点击前准入、拒绝时不改变高亮、重复点击通知；程序静默定位与业务选择分开。
- 六种图文排列、普通/选中图片及颜色、字体/图标尺寸/间距/边距/栏高；默认上图下文的位置保持原样。
- 栏背景图、普通毛玻璃、调色遮罩；系统“减少透明度”开启时回退实色，不默认分配模糊层。
- 单项动态更新标题、图片、角标、禁用状态及完整样式；单项普通/选中字体、颜色、背景可独立配置，不重建其它按钮或导航栈。
- 红点、文本/数字角标、可按项设置颜色及文字角标高度；普通入口依附图标/文字右上角，有背景的定制/凸起按钮依附可见轮廓，数值上限由业务处理。
- 任意槽位、多凸起、圆形/圆角矩形按钮；默认等宽槽位，实际按钮可调整尺寸/抬升，超出底栏的真实按钮区域可点击。
- 缩放、弹簧、轻跳三种预设点击动画，支持全局/单项配置和自定义图标动画回调；默认关闭，尊重系统“减少动态效果”。
- push/pop 跟随底栏隐藏配置，处理交互返回取消；转发原导航代理并在移除后恢复。
- 子页面出现/消失事件配对；状态栏、Home Indicator 和方向由当前入口提供。
- 安全区、窗口尺寸变化、RTL、基础 VoiceOver 选中/禁用状态；按钮栏可脱离容器单独使用。

## 与参考组件的能力差异

下表跟踪主要公开能力的完成情况，不把“外部可以自行添加子视图”算作组件已经支持。
比较依据为下方官方说明和公开头文件，不代表已经在本项目运行验证第三方组件的全部行为。

### 相比 AxcAE_TabBar

| 参考组件的能力 | XBTabBar 当前边界 |
| --- | --- |
| 任意位置、多个不同形状的凸起按钮 | 已支持任意槽位、多凸起、圆形/圆角矩形、越界点击、独立操作或切页；不支持任意不规则形状路径 |
| 图上文下、文上图下、横向排列、纯图、纯文 | 已支持六种排列，横向跟随 RTL；缺少图片/标题时不保留空占位 |
| 按钮在单元格中的多方向对齐及独立尺寸 | 槽位等宽，实际按钮可独立设置尺寸、圆角并上抬；宽度不超过槽位，不能覆盖相邻入口 |
| 栏背景图、模糊遮罩、单项背景图及选中背景色 | 已支持，普通/选中按钮背景与栏背景分开管理 |
| 单项字体、颜色、内部组件尺寸等独立配置 | 已通过完整 style 副本支持；nil 表示跟随全局，不隐式合并字段 |
| 徽标左/中/右位置 | 自动跟随图标、文字或定制按钮可见轮廓的物理右上角，不提供切到左/中位置的配置 |
| 弹簧、缩放、渐变等预设点击动画 | 已支持缩放、弹簧、轻跳及单项覆盖；渐变等其它效果通过自定义回调接入 |
| 直接访问内部图标/标题控件 | 有意保持私有，业务通过配置更新；不建议为了对齐 API 而暴露可变内部状态 |

来源：[AxcAE_TabBar 功能说明](https://github.com/axclogo/AxcAE_TabBar#功能介绍)。

### 相比 CYLTabBarController

| 参考组件的能力 | XBTabBar 当前边界 |
| --- | --- |
| PlusButton 自定义位置/尺寸、越界点击、独立动作或关联页面 | 已通过局部 item/style 配置实现，不需要全局 PlusButton 注册或单例 |
| 内置 Lottie 配置和播放管理 | 提供原生预设和自定义图标动画回调，不加载动画文件或管理 Lottie 视图 |
| 液态玻璃与扁平样式切换 | 已有普通毛玻璃，没有液态玻璃或玻璃选中效果 |
| 仅图标自动居中、图标与标题位置调整 | 已有纯图/纯文居中、六种排列及边距配置；没有图标/标题各自任意坐标偏移 |
| 自定义角标视图、位置/字体/形状、角标动画及恢复显示 | 当前为固定 UILabel 角标，可按项设置颜色/文字角标高度；没有其它扩展 |
| 面向 UIView、UITabBarItem、UIBarButtonItem 的通用角标扩展 | 有意不扩展到全局控件，角标职责限制在本组件 |
| CocoaPods / SPM / Carthage 等发布方式 | 支持源码复制接入；独立 Demo 内附离线依赖、XCTest 和参与编译的 Swift 示例，尚未发布包管理器版本 |

来源：[CYLTabBarController 官方说明](https://github.com/ChenYilong/CYLTabBarController)、[角标协议](https://github.com/ChenYilong/CYLTabBarController/blob/master/CYLTabBarController/CYLBadgeProtocol.h)。

两者的系统 TabBar 集成方式不等于本组件“6～7 个业务页面全部直显”的容器方案。
本组件不准备恢复系统 More、全局 PlusButton 注册或全局角标分类；如需补齐视觉能力，优先扩展显示配置和按钮栏，不改变容器及业务准入链路。

## 最小接入

```objc
#import "XBTabContainerViewController.h"

XBTabContainerViewController *tabs = [XBTabContainerViewController new];
UINavigationController *home = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
UINavigationController *mine = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];

XBTabBarItem *homeItem = [[XBTabBarItem alloc] initWithIdentifier:@"home" title:@"首页"
    image:[[UIImage imageNamed:@"home"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
    selectedImage:[UIImage imageNamed:@"home_selected"]];
XBTabBarItem *mineItem = [[XBTabBarItem alloc] initWithIdentifier:@"mine" title:@"我的"
    image:[UIImage imageNamed:@"mine"] selectedImage:[UIImage imageNamed:@"mine_selected"]];
[tabs setViewControllers:@[home, mine] tabBarItems:@[homeItem, mineItem]];
self.window.rootViewController = tabs;
```

控制器按 kind=Page 的按钮顺序对应，kind=Action 不占页面数组；identifier 非空且唯一，重排时保留原页面 identifier。
不要把会变化成“刷新”的显示标题作为标识。仅设置 `viewControllers` 也可以，组件从各页面的 `tabBarItem` 生成默认配置；自动标识在同一容器内随控制器对象保持稳定，不随数组位置改变。跨对象重建或跨启动恢复时应提供明确的 identifier，或唯一非空的 `restorationIdentifier`。
将三个 `.m` 加入目标 Target 并链接 Masonry；所有 UI 和配置操作在主线程执行。

## 点击、拦截与重复点击

```objc
tabs.selectionDelegate = self;

- (BOOL)tabContainer:(XBTabContainerViewController *)container
   shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    return [self canOpenPageWithIdentifier:item.identifier];
}

- (void)tabContainer:(XBTabContainerViewController *)container
      didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected {
    if (reselected) {
        [self refreshPageWithIdentifier:item.identifier];
    }
}
```

顺序：按标识找入口 → 准入判断 → 提交选择/高亮 → 可选动画 → 业务回调。
拒绝时保持原高亮；重复点击回调不重复触发页面出现事件。
准入回调不等待网络、不再次同步选择；需要登录时先返回 NO，登录后重新选择。
一次激活固定使用开始时的 delegate，保证准入与完成回调配对；回调内更换 delegate 从下一次激活生效。
以上是 Page 的选择流程；Action 通过同一准入后只执行动画扩展和 `didTriggerActionItem`，不会提交选择或触发 `didSelectItem`。

```objc
[tabs selectTabWithIdentifier:@"mine"]; // 与点击相同，经过准入和重复点击逻辑。
tabs.selectedIndex = 1;                 // 静默定位，不触发点击/刷新/权限。
tabs.selectedViewController = mine;      // 同上，仅接受已在容器中的控制器。
```

## 凸起按钮与独立操作

```objc
XBTabBarItem *publish = [[XBTabBarItem alloc] initWithIdentifier:@"publish" title:@"发布"
    image:[UIImage systemImageNamed:@"plus"] selectedImage:nil kind:XBTabBarItemKindAction];
XBTabBarItemStyle *raised = [tabs.tabBarAppearance copy];
raised.layout = XBTabBarItemLayoutImageOnly;
raised.contentInsets = UIEdgeInsetsZero;
raised.buttonSize = CGSizeMake(56, 56);
raised.raisedHeight = 12;
raised.cornerRadius = 28;
raised.normalBackgroundColor = UIColor.systemOrangeColor;
raised.normalColor = UIColor.whiteColor;
publish.style = raised;
publish.badgeValue = @"8";

// 操作插在任意位置，不添加空白控制器；多个入口都可配置凸起。
[tabs setViewControllers:@[home, mine] tabBarItems:@[homeItem, publish, mineItem]];
tabs.selectionDelegate = self;

- (void)tabContainer:(XBTabContainerViewController *)container
 didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    if ([item.identifier isEqualToString:@"publish"]) {
        [self showPublishPage];
    }
}
```

| 概念 | 上述示例的下标 |
| --- | --- |
| `viewControllers` / 容器 `selectedIndex` | home=0、mine=1，不包含 publish |
| 按钮栏 `items` / 按钮栏 `selectedIndex` / delegate 的 index | home=0、publish=1、mine=2 |
| 点击 publish | 当前页面/高亮不变，只回调操作；没有操作接收方法时返回 NO |

通过 `selectTabWithIdentifier:` 可走相同的页面/操作激活流程，推荐业务路由使用稳定标识，不手工换算下标。
`kind` 创建后不可变；调整入口类型、顺序、增删时必须调用容器的 `setViewControllers:tabBarItems:`，不要直接修改容器内按钮栏的 `setItems:`。
仅更新样式、文案、图片、角标或 enabled 可以继续 `updateItem:`。

`buttonSize` 的0分量沿用槽位宽度或按钮区高度，宽度上限是当前槽位宽，不挤占其它入口。
按钮底边位于槽位底边上方 `raisedHeight` 点；因此56高按钮放在49高栏中，再上抬12点，顶部会高出栏19点。
凸起不增加栏高或页面底部安全区；按钮不会向下伸进 Home Indicator，页面可见区域与原来一致。
圆角只裁剪背景，不裁剪角标；点击按圆角轮廓判断，圆形透明角不会抢占凸起区域下面的页面手势。
容器已覆盖凸起部分的命中；单独嵌入 `XBTabBarView` 时，外层父视图必须包含凸起区域且不要裁剪它，组件不会修改全局窗口或其它控件的 hitTest。

## 外观、角标、动态文案

```objc
XBTabBarAppearance *style = [tabs.tabBarAppearance copy];
style.contentHeight = 49; // 仅按钮区，不含底部安全区。
style.selectedColor = UIColor.systemOrangeColor;
style.imageSize = CGSizeMake(23, 23);
tabs.tabBarAppearance = style;

[tabs.tabBar setBadgeValue:@"8" forIdentifier:@"mine"];
[tabs.tabBar setBadgeValue:@"" forIdentifier:@"mine"];  // 红点。
[tabs.tabBar setBadgeValue:nil forIdentifier:@"mine"]; // 隐藏。

XBTabBarItem *item = [tabs.tabBar itemForIdentifier:@"home"];
item.title = @"刷新";
[tabs.tabBar updateItem:item]; // 不重建页面、不改变入口标识。
```

外观使用 UIKit 动态色，接入方可替换自己的语义色。修改配置后重新应用，不依赖 KVO 或 PCH。
数字上限、0是否隐藏、选中时是否清除未读均是业务规则，组件不读取或请求这些数据。

### 角标的视觉锚点

| 场景 | 定位规则 |
| --- | --- |
| 上图下文、仅图 | 贴近图标右上角，不以整列点击范围为锚点 |
| 上文下图 | 跟随文字右上角，不再跟随下方图标 |
| 图在前、文字在后 | 跟随文字右上角并略上抬，窄列中也不遮字 |
| 文字在前、图在后 | 保持图标右上角，略上抬避免压住标题 |
| 仅文字或无图标 | 文字右侧留2点间隔，在其右上角显示 |
| 有可见背景的定制/凸起按钮 | 沿背景右上圆角定位，圆形约一点半方向 |

普通图标的角标左边缘可轻压图标3点，数字通常向右展开；RTL 仍是可见内容的物理右上角。
角标不改变图文的固有宽高；到达槽位边缘时优先调整角标位置/宽度，不通过挤压标题腾空间，也不侵入相邻入口。
圆角锚点与背景共用 `min(cornerRadius, width/2, height/2)` 的几何规则，按钮变宽、变窄时仍跟随实际轮廓。
定制按钮背景为透明且没有背景图时，仍以图标/文字定位，不把看不见的按钮矩形作为锚点。

角标可在独立 `XBTabBarDemo` 中切换数字、红点和隐藏，并结合六种布局、RTL、深浅色检查实际显示；文档不引用尚未提供的截图资源。

## 图文排列与单项覆盖

| layout | 显示方式 |
| --- | --- |
| XBTabBarItemLayoutImageAboveTitle | 上图下文，默认 |
| XBTabBarItemLayoutTitleAboveImage | 上文下图 |
| XBTabBarItemLayoutImageLeading | 图在前、文在后，RTL 时镜像 |
| XBTabBarItemLayoutTitleLeading | 文在前、图在后，RTL 时镜像 |
| XBTabBarItemLayoutImageOnly | 仅图标，内容区域居中 |
| XBTabBarItemLayoutTitleOnly | 仅标题，内容区域居中 |

```objc
XBTabBarAppearance *appearance = [tabs.tabBarAppearance copy];
appearance.layout = XBTabBarItemLayoutImageAboveTitle;
tabs.tabBarAppearance = appearance;

XBTabBarItem *item = [tabs.tabBar itemForIdentifier:@"mine"];
// 完整复制当前按钮样式后修改；其中的栏背景/栏高不会作用于单项。
XBTabBarItemStyle *single = [tabs.tabBarAppearance copy];
single.layout = XBTabBarItemLayoutImageLeading;
single.imageSize = CGSizeMake(20, 20);
single.titleFont = [UIFont systemFontOfSize:12];
single.selectedTitleFont = [UIFont boldSystemFontOfSize:12];
single.selectedColor = UIColor.systemOrangeColor;
single.selectedBackgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.08];
item.style = single;
[tabs.tabBar updateItem:item];

// 恢复跟随全局样式。
item.style = nil;
[tabs.tabBar updateItem:item];
```

`style == nil` 才会持续跟随全局修改；指定 style 后它是完整样式快照，后续全局主题/布局变化不会覆盖它。
修改单项配置后必须 `updateItem:`；修改全局外观后重新赋给容器的 `tabBarAppearance`。
容器接入时不要只改 `tabs.tabBar.appearance.contentHeight`，避免按钮区高度与容器安全区不同步。

## 栏背景、背景图与普通毛玻璃

```objc
XBTabBarAppearance *appearance = [tabs.tabBarAppearance copy];
appearance.backgroundImage = [UIImage imageNamed:@"tab_background"];
appearance.barBackgroundImageContentMode = UIViewContentModeScaleAspectFill;
appearance.backgroundBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
appearance.backgroundOverlayColor = [UIColor.whiteColor colorWithAlphaComponent:0.12];
tabs.tabBarAppearance = appearance;
```

从下到上依次为：底色/下方页面 → 栏背景图 → 模糊层 → 调色遮罩 → 分割线 → 按钮自身背景及图文/角标。
凸起按钮背景会遮住经过它的分割线，不会出现分割线穿过圆形按钮的情况。
背景图和模糊可独立使用，也可叠加；背景覆盖底部安全区，不扩展按钮点击区域。
模糊开启时栏底色透明，让模糊能采样背景图或下方内容；不要用不透明遮罩盖住模糊后再期待看到效果。
系统开启“减少透明度”时关闭模糊，使用 `backgroundColor` 回退；默认回退色为不透明的系统背景色。
清除 `backgroundImage`、`backgroundBlurEffect`、`backgroundOverlayColor` 即可回到默认纯色背景，原图像和模糊 effect 会释放。
单项背景图使用 `style.normalBackgroundImage` / `selectedBackgroundImage`，与栏的 `backgroundImage` 分开配置。

## 可选动画

默认值为 `XBTabBarItemAnimationNone`，现有页面无需修改；开启预设不需要额外 SDK。

| 预设 | 效果 |
| --- | --- |
| `XBTabBarItemAnimationNone` | 关闭预设 |
| `XBTabBarItemAnimationScale` | 先缩小再恢复 |
| `XBTabBarItemAnimationSpring` | 缩小后弹簧回弹 |
| `XBTabBarItemAnimationBounce` | 向上轻跳并小幅回跳 |

```objc
// 全局开启；tabBarAppearance 按值复制，修改后要重新赋回。
XBTabBarAppearance *appearance = [tabs.tabBarAppearance copy];
appearance.selectionAnimationType = XBTabBarItemAnimationScale;
tabs.tabBarAppearance = appearance;

// 单项使用弹簧。保留该项现有完整样式，无覆盖时才复制全局样式。
XBTabBarItem *item = [tabs.tabBar itemForIdentifier:@"home"];
if (item != nil) {
    XBTabBarItemStyle *style = [(item.style ?: tabs.tabBarAppearance) copy];
    style.selectionAnimationType = XBTabBarItemAnimationSpring;
    item.style = style;
    [tabs.tabBar updateItem:item];
}
// 某项不播放：将该项 style.selectionAnimationType 设为 None 并 updateItem:。
// 恢复持续跟随全局：将 item.style 设为 nil 并 updateItem:。
```

优先动画可见图标，无图标时动画文字；按钮背景、角标和点击范围不参与动画。
连续点击替换组件自己的动画，不排队，不修改视图的模型层 transform；结束或中断不会残留缩放、位移。
关闭某项预设/禁用入口会停止该项的预设；系统中途开启“减少动态效果”会停止全部正在播放的预设。

已有自定义回调优先于预设，不叠加；移除回调（设为 nil）后恢复使用预设。回调仍传入原图标视图，以兼容已有接入，文字回退只适用于预设：

```objc
tabs.tabBar.selectionAnimation = ^(UIView *imageView, BOOL reselected) {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    animation.values = @[@1, @1.15, @1];
    animation.duration = 0.2;
    [imageView.layer addAnimation:animation forKey:@"selection"];
};
```

页面切换、重复点击以及独立 Action 入口，均在准入通过后才播放；布局/角标更新、静默同步、禁用入口、系统“减少动态效果”及 UIView 全局关闭动画时不启动动画。
独立使用 XBTabBarView 时，在 itemTapHandler 中确认接受点击后调用 animateSelectionAtIndex:reselected:，避免被业务拒绝的点击仍播放动画。
需要 Lottie 时仍在回调扩展点接入，不增加组件依赖；自定义动画的中断/恢复由调用方管理，组件只移除键为 `XBTabBar.selection` 的自身动画。

## 导航与安全区

- push/pop 跟随 `hidesBottomBarWhenPushed`，交互返回取消按真实栈恢复底栏。
- 原导航 delegate 的业务/自定义转场方法通过内部代理转发；入口移除时恢复原代理。挂载期间不要另行替换 `navigation.delegate`。
- 保存并恢复页面原有 `additionalSafeAreaInsets`，只增加按钮区高度。
- 背景铺满底部安全区，按钮不进入 Home Indicator 或侧边系统区域；等宽约束自动跟随窗口变化，RTL 下按语义方向排列。
- 状态栏和方向继续由当前页面决定；组件不扣减顶部/左右安全区，也不设置 Duo 状态栏方向。
- `controller.xb_tabContainer` 查找所属容器；`XBSelectedTabViewController` 兼容系统/自有容器。
- 组件已统一使用 XB 前缀；项目业务类 CXTabBarViewController 不属于组件，迁移其它项目无需复制。

参考：[AxcAE_TabBar](https://github.com/axclogo/AxcAE_TabBar)、[CYLTabBarController](https://github.com/ChenYilong/CYLTabBarController)。

## 迁移后的回归重点

- 4/5/6/7入口都能直接点到最后一项，图标高亮与实际页面一致。
- 准入拒绝不切页；静默选择不请求权限、不触发刷新；重复点击不重复发送页面出现事件。
- 重排、新控制器替换、入口删除及空配置均正确恢复标识/清理旧页面。
- push/pop、侧滑完成和取消、全屏模态展示不会残留底栏或底部空位。
- 导航原代理仍能处理自定义转场，入口移除/容器释放后代理和原边距恢复。
- 深浅色、动态文案、红点/数字、禁用状态、RTL，以及窗口宽度和安全区变化。
- 六种排列、缺图/缺标题、单项覆盖/恢复继承、选中字体/背景切换、运行时 RTL、背景叠层及“减少透明度”回退。
- 角标在六种布局、RTL 中跟随实际图文，凸起时跟随可见轮廓；横排标题不因角标变窄或变矮；多凸起越界点击、圆形透明角穿透、隐藏/禁用栏不拦截页面。
- Page/Action 混排、前置/中置/尾部操作、操作准入拒绝、不改变选中页、重排后按页面标识恢复及没有页面的纯操作配置。

当前项目还需单独回归：游客权限弹窗、登录后重建、启航入口动态增删、Deep Link、咨询未读角标和音频悬浮窗位置。


## 配置快照与初始化

- `tabBar.items`、`itemForIdentifier:` 返回 item 及其 style 的独立副本。修改读取结果不会直接改变组件，须调用 `updateItem:`。
- `tabBar.appearance` 和 `container.tabBarAppearance` 的读写均复制配置。读取、修改、重新赋值是统一的外观更新方式；容器接入时使用 `tabBarAppearance` 更新高度和安全区。
- 支持代码创建及 Storyboard/XIB 的 `initWithCoder:` 初始化。解码建立默认状态，入口、图片、delegate 和业务选择状态须由接入方重新配置，不自动序列化整个组件。
- 标识重复、页面数不匹配和控制器归属错误在 Debug 断言，Release 拒绝此次替换并保留已有配置；禁止将容器自身或其祖先作为入口。
- 组件所有配置和 UI 更新须在主线程执行。

## 独立 Demo 与验证

独立工程目录为 `XBTabBarDemo`，打开 `XBTabBarDemo.xcodeproj`，选择同名 scheme 和 iPhone/iPad 模拟器后运行。工程内提供完整组件源码及 Masonry，不需要 CocoaPods 或网络下载；真机运行需自行选择 Development Team。

`Tests/XBTabBarTests.m` 是组件回归测试源文件，Demo 的 `XBTabBarTests` target 编译同一份测试。覆盖默认标识重排/移除恢复、显式标识重建、配置深复制、外观与安全区、解码初始化、禁用/拒绝/静默选择、Action 混排、准入中重建、出现事件和导航代理恢复。Demo 的 `SwiftInteropCheck.swift` 实际参与编译，验证 Swift 接入接口。

测试在 Xcode 中使用 Product → Test（⌘U）。组件部署目标为 iOS 15；测试宿主可使用当前 Xcode 支持的模拟器。交互返回取消、辅助功能切换及窄屏下多入口的视觉效果仍需按上文列表人工回归。

版本记录见 [CHANGELOG.md](CHANGELOG.md)，许可见 [LICENSE](LICENSE)。Masonry 使用其自身 MIT 许可，Demo 在 `Vendor/Masonry/LICENSE` 保留原文。
