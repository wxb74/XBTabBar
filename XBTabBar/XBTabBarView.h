#import <UIKit/UIKit.h>
#import "XBTabBarItem.h"

NS_ASSUME_NONNULL_BEGIN

/// 可单独使用的横向按钮栏；仅依赖 UIKit/Masonry，不切控制器、不请求权限、不识别业务通知。
/// 所有配置和 UI 更新均在主线程调用。按钮区位于顶部，底部剩余空间仅绘制背景。
/// 背景支持图片和普通毛玻璃；图文排列与单项覆盖见 XBTabBarAppearance / XBTabBarItem.style。
@interface XBTabBarView : UIView
/// 返回包含 item/style 副本的快照；修改快照后通过 updateItem: 应用。
@property (nonatomic, copy, readonly) NSArray<XBTabBarItem *> *items;
/// getter/setter 均复制配置；修改后重新赋值，避免内部状态与显示不同步。
@property (nonatomic, copy) XBTabBarAppearance *appearance;
/// 按钮栏下标（含操作按钮）；Action 不可选中。NSNotFound 表示未选中，setter 不发送点击回调。
@property (nonatomic, assign) NSUInteger selectedIndex;
/// 单独使用时由外部处理；挂在 XBTabContainerViewController 时由容器持有此回调。
@property (nonatomic, copy, nullable) void (^itemTapHandler)(NSString *identifier, NSUInteger index);
/// 点击被容器接受后的自定义图标动画；设置后替代 selectionAnimationType 预设，不叠加。
/// 回调参数仍是原图标视图（兼容已有接入）；仅文字的自动回退只适用于预设动画。
/// 程序同步选择、禁用入口、系统“减少动态效果”或 UIView 全局关闭动画时不调用。
@property (nonatomic, copy, nullable) void (^selectionAnimation)(UIView *imageView, BOOL reselected);
/// 替换按钮配置，保留仍存在的选中 identifier；空数组安全清空。
- (void)setItems:(NSArray<XBTabBarItem *> *)items;
/// 按稳定标识查询的副本；不存在返回 nil。
- (nullable XBTabBarItem *)itemForIdentifier:(NSString *)identifier;
/// 更新文案、图片、角标、enabled 或样式，不重建其它按钮；不能修改既有标识的 kind。
- (void)updateItem:(XBTabBarItem *)item;
/// nil 隐藏、空字符串显示红点；不带业务数字上限或“选中隐藏”规则。
- (void)setBadgeValue:(nullable NSString *)value forIdentifier:(NSString *)identifier;
/// 由容器确认选择后调用；依次采用自定义回调、单项/全局预设，不改变选择或回调点击。
/// 独立使用按钮栏时，由 itemTapHandler 在业务确认接受点击后主动调用。
- (void)animateSelectionAtIndex:(NSUInteger)index reselected:(BOOL)reselected;
/// 越界点击只覆盖实际凸起按钮。独立嵌入时，外层父视图须包含凸起区域且不要裁剪该区域。
@end

NS_ASSUME_NONNULL_END
