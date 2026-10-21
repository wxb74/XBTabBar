#import <UIKit/UIKit.h>
#import "XBTabBarView.h"

NS_ASSUME_NONNULL_BEGIN

/// 多入口页面容器，不使用 UITabBarController，因此入口数量不会触发系统 More。
/// 所有配置和切换在主线程进行。按钮栏/容器仅负责 UI，权限和重复点击刷新由 delegate 决定。
@class XBTabContainerViewController;

@protocol XBTabContainerDelegate <NSObject>
@optional
/// 页面和操作入口均先询问；index 是按钮栏下标（含操作按钮），NO 时不切页、不执行操作、不闪动高亮。
- (BOOL)tabContainer:(XBTabContainerViewController *)container shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index;
/// 仅页面选择通过后通知；index 是按钮栏下标。reselected=YES 表示重复点击当前页。
- (void)tabContainer:(XBTabContainerViewController *)container didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected;
/// 独立操作通过准入后回调；不改变 selectedIndex、不发送页面生命周期，也不调用 didSelectItem。
- (void)tabContainer:(XBTabContainerViewController *)container didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index;
@end

@interface XBTabContainerViewController : UIViewController <UINavigationControllerDelegate>

/// 仅包含页面入口的控制器，按页面入口在按钮栏中的顺序排列；操作入口不需要占位控制器。
@property (nonatomic, copy) NSArray<UIViewController *> *viewControllers;
/// 当前页面在 viewControllers 中的下标，不含操作按钮；没有页面时为 NSNotFound，越界设置无效。
@property (nonatomic, assign) NSUInteger selectedIndex;
/// 当前选中页面。设置时必须是 viewControllers 中的对象。
@property (nonatomic, strong, nullable) UIViewController *selectedViewController;
/// 底部栏是自己的 UIView，不使用 UITabBar、不触发 More；包含49点按钮区和系统底部安全区。
@property (nonatomic, strong, readonly) XBTabBarView *tabBar;
@property (nonatomic, weak, nullable) id<XBTabContainerDelegate> selectionDelegate;
/// 读取返回独立副本；设置同时更新宿主高度和子控制器底部避让，修改后重新赋值应用。
@property (nonatomic, copy) XBTabBarAppearance *tabBarAppearance;
/// 当前选中入口的导航控制器，不依赖入口下标，也不存在 More 分支。
@property (nonatomic, readonly, nullable) UINavigationController *currentNavigationController;
/// 底部栏是否因当前导航栈的 hidesBottomBarWhenPushed 配置而隐藏。
@property (nonatomic, readonly, getter=isTabBarHidden) BOOL tabBarHidden;

/// 更新底部栏和内容安全区域；通常由导航代理自动调用，外部不要直接改 tabBar.hidden。
- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animated;

/// 推荐初始化/重建入口：控制器仅与 kind=Page 的配置顺序对应，标识不可重复；Action 可插在任意位置。
/// 重排后保留原页面标识的选择；全为 Action 时允许控制器数组为空。
/// 仅设置 viewControllers 时也可使用，会从每个控制器的 UITabBarItem 生成默认显示配置。
/// 默认标识随控制器对象保留；跨对象重建/跨启动恢复时请提供稳定 identifier 或 restorationIdentifier。
- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers tabBarItems:(NSArray<XBTabBarItem *> *)items;
/// 按标识激活页面或操作，均经过 shouldSelect；操作不改变选中页。没有操作回调、未找到、禁用或被拦截返回 NO。
/// 直接设置 selectedIndex/selectedViewController 是静默同步，不触发上述业务回调。
- (BOOL)selectTabWithIdentifier:(NSString *)identifier;

@end

@interface UIViewController (XBTabContainer)
/// 沿父容器/展示关系查找自定义 Tab 容器；不改写 UIKit 的 tabBarController 属性。
@property (nonatomic, readonly, nullable) XBTabContainerViewController *xb_tabContainer;
@end

/// 读取自定义或系统 Tab 容器的选中页，供公共的顶层页面/播放器遍历代码共用；非 Tab 容器返回 nil。
FOUNDATION_EXPORT UIViewController * _Nullable XBSelectedTabViewController(UIViewController * _Nullable controller);

NS_ASSUME_NONNULL_END
