#import <UIKit/UIKit.h>
#import "XBTabBarItem.h"

NS_ASSUME_NONNULL_BEGIN

/// 整条栏的位置；与 XBTabBarItemLayout（单个按钮的图文排列）用途不同。
typedef NS_ENUM(NSUInteger, XBTabBarPlacement) {
    XBTabBarPlacementAutomatic,     ///< 容器读取系统建议，推荐默认值。
    XBTabBarPlacementBottom,        ///< 底部横栏，按钮区下方包含底部安全区背景。
    XBTabBarPlacementFloatingLeft,  ///< 物理左下侧的纵向胶囊，不随 RTL 镜像。
    XBTabBarPlacementFloatingRight, ///< 物理右下侧的纵向胶囊，不随 RTL 镜像。
};

/// iOS 27.1 根据系统 verticalBarEdge 决定物理侧边；旧系统、普通设备返回 Bottom。
FOUNDATION_EXPORT XBTabBarPlacement XBTabBarPlacementForTraits(UITraitCollection *traits);

/**
 只负责按钮展示和点击的 UIView。需要页面切换、Duo 自动位置、安全区/键盘/折叠区域避让时，
 优先使用 XBTabContainerViewController；其 tabBar 已管理好这些职责。

 独立接入时：设置 items/appearance，给视图设置约束或 frame，并在 itemTapHandler 中处理点击；
 宿主自行决定 vertical、栏尺寸、系统区域避让及页面安全区。确认页面选择后设置 selectedIndex，
 再调用 animateSelectionAtIndex:reselected:；Action 只执行操作，不设置为选中项。
 所有配置在主线程调用。配置按副本保存，修改后通过对应 setter/updateItem: 提交。
 */
@interface XBTabBarView : UIView
/// 只控制排列方向，不自动移动视图。由容器托管时不要自行设置。
/// 纵向按当前状态显示图标，无可显示图标时回退标题，完整标题始终供 VoiceOver 读取。
/// 空间不足时纵向滚动，所有入口仍可访问；切换不会重建按钮或修改 item.style。
@property (nonatomic, assign, getter=isVertical) BOOL vertical;
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
/// 横栏可命中真实凸起按钮；独立嵌入时父视图须包含凸起区域且不裁剪。竖栏仅在胶囊可见范围内命中。
@end

NS_ASSUME_NONNULL_END
