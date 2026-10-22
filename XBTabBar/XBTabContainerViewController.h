#import <UIKit/UIKit.h>
#import "XBTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

@class XBTabContainerViewController;

/// 接入业务权限、重复点击刷新和独立操作。selectionDelegate 为弱引用，接入方应持有代理对象。
/// 回调里的 index 是按钮栏下标，包含 Action；路由建议使用 item.identifier，避免依赖固定下标。
@protocol XBTabContainerDelegate <NSObject>
@optional
/// 页面和操作入口均先询问；index 是按钮栏下标（含操作按钮），NO 时不切页、不执行操作、不闪动高亮。
- (BOOL)tabContainer:(XBTabContainerViewController *)container shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index;
/// 仅页面选择通过后通知；index 是按钮栏下标。reselected=YES 表示重复点击当前页。
- (void)tabContainer:(XBTabContainerViewController *)container didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected;
/// 独立操作通过准入后回调；不改变 selectedIndex、不发送页面生命周期，也不调用 didSelectItem。
- (void)tabContainer:(XBTabContainerViewController *)container didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index;
@end

/**
 多入口页面容器，负责页面切换、导航代理转发、栏布局与内容避让；仅依赖 UIKit/Masonry。
 最低部署目标为 iOS 15；Duo 自动侧栏需要使用 SDK 27.1+ 构建，并在 iOS 27.1+ 上运行。
 所有配置和 UI 更新在主线程调用。不使用 UITabBarController，不会因入口超过5个产生 More。

 推荐接入顺序：
 1. 每个一级页面创建自己的 UINavigationController，并为入口提供不会随标题变化的 identifier。
 2. 用 setViewControllers:tabBarItems: 一次配置页面和入口，再将容器放入窗口或正常的父子控制器层级。
 3. 需要登录拦截、重复点击刷新或 Action 时设置 selectionDelegate。
 4. 读取 tabBarAppearance 的副本，修改后重新赋值。业务内容约束到自身 safeAreaLayoutGuide。

 最小示例（homeController 为业务页面）：
 @code
 XBTabContainerViewController *tabs = [XBTabContainerViewController new];
 UINavigationController *home = [[UINavigationController alloc] initWithRootViewController:homeController];
 XBTabBarItem *item = [[XBTabBarItem alloc] initWithIdentifier:@"home" title:@"首页"
                                                     image:[UIImage systemImageNamed:@"house"] selectedImage:nil];
 [tabs setViewControllers:@[home] tabBarItems:@[item]];
 window.rootViewController = tabs;
 @endcode

 Duo 默认走 Automatic；布局变化时不要重建页面或重复配置入口。
 这是自定义容器，子页通过 xb_tabContainer 查找它，不能依赖系统 tabBarController 属性。
 导航 delegate 应在配置入口前设置，容器会代理并转发；接入后直接替换导航 delegate 会中断自动隐藏。
 */
@interface XBTabContainerViewController : UIViewController <UINavigationControllerDelegate>
/// 默认 Automatic。SDK及运行系统均为27.1+时跟随 verticalBarEdge，普通设备/旧SDK回退 Bottom。
/// 外屏和内屏横屏通常使用侧栏，内屏竖屏使用横栏；Split View 跟随系统指定的物理外侧。
/// 显式位置用于宿主有意覆盖系统建议或测试；不按屏幕宽度、机型或 RTL 猜测侧栏位置。
@property (nonatomic, assign) XBTabBarPlacement tabBarPlacement;
/// 最近一次布局解析的位置；挂窗并完成布局后读取，避免把启动期值当成最终设备布局。
@property (nonatomic, readonly) XBTabBarPlacement resolvedTabBarPlacement;
/// 当前页面的额外避让，不含系统原始安全区；系统已为侧栏留足空间时可能为0，侧栏模式 bottom=0。
/// 仅供查询，业务应约束到页面自身安全区，不要再次叠加此值、栏高度或修改容器管理的边距。
@property (nonatomic, readonly) UIEdgeInsets tabBarContentInsets;

/// 仅包含页面入口的控制器，按页面入口在按钮栏中的顺序排列；操作入口不需要占位控制器。
@property (nonatomic, copy) NSArray<UIViewController *> *viewControllers;
/// 当前页面在 viewControllers 中的下标，不含 Action；与按钮栏/代理回调的下标不是同一种下标。
/// 没有页面时为 NSNotFound，越界设置无效；直接赋值为静默同步，不走权限、刷新或动画回调。
@property (nonatomic, assign) NSUInteger selectedIndex;
/// 当前选中页面。设置时必须是 viewControllers 中的对象；同 selectedIndex，直接赋值为静默同步。
@property (nonatomic, strong, nullable) UIViewController *selectedViewController;
/// 读取会加载容器视图。可更新单项/角标和选择动画；栏的 frame、vertical、hidden 和 items 结构由容器管理。
/// 外观通过 tabBarAppearance 更新；入口结构通过 setViewControllers:tabBarItems: 更新。
@property (nonatomic, strong, readonly) XBTabBarView *tabBar;
@property (nonatomic, weak, nullable) id<XBTabContainerDelegate> selectionDelegate;
/// 读取返回独立副本；设置同时更新栏布局和子控制器避让，修改后重新赋值应用。
@property (nonatomic, copy) XBTabBarAppearance *tabBarAppearance;
/// 当前选中入口的导航控制器，不依赖入口下标，也不存在 More 分支。
@property (nonatomic, readonly, nullable) UINavigationController *currentNavigationController;
/// 导航/宿主请求的隐藏状态；横栏和侧栏共用。无入口或空间不足时，实际栏也可能暂时不可见。
@property (nonatomic, readonly, getter=isTabBarHidden) BOOL tabBarHidden;

/// 同时更新栏和内容避让。详情页请在 push 前设置 hidesBottomBarWhenPushed=YES，由导航代理自动管理。
/// 宿主可主动调用；之后导航切换会重新按导航栈配置判断，不能通过直接改 tabBar.hidden 代替。
- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animated;

/// 推荐初始化/重建入口：控制器仅与 kind=Page 的配置顺序对应，标识不可重复；Action 可插在任意位置。
/// 例如按钮为 [首页, 发布(Action), 我的] 时，控制器数组为 [首页导航, 我的导航]。
/// 重排后保留原页面标识的选择；全为 Action 时允许控制器数组为空。
/// 仅设置 viewControllers 时也可使用，会从每个控制器的 UITabBarItem 生成默认显示配置。
/// 默认标识随控制器对象保留；跨对象重建/跨启动恢复时请提供稳定 identifier 或 restorationIdentifier。
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers tabBarItems:(NSArray<XBTabBarItem *> *)items;
/// 按标识激活页面或操作，均经过 shouldSelect；操作不改变选中页。
/// 未找到、禁用、被拦截，或 Action 缺少操作回调时返回 NO。
/// 直接设置 selectedIndex/selectedViewController 是静默同步，不触发上述业务回调。
/// 登录未完成时 shouldSelect 返回 NO，登录成功后再调用本方法；不要在 shouldSelect 内同步递归选择。
- (BOOL)selectTabWithIdentifier:(NSString *)identifier;

@end

@interface UIViewController (XBTabContainer)
/// 沿父容器/展示关系查找自定义 Tab 容器；不改写 UIKit 的 tabBarController 属性。
@property (nonatomic, readonly, nullable) XBTabContainerViewController *xb_tabContainer;
@end

/// 读取自定义或系统 Tab 容器的选中页，供公共的顶层页面/播放器遍历代码共用；非 Tab 容器返回 nil。
FOUNDATION_EXPORT UIViewController * _Nullable XBSelectedTabViewController(UIViewController * _Nullable controller);

NS_ASSUME_NONNULL_END
