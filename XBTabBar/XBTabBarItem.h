#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 页面入口与操作入口分开：操作不占用页面数组下标，也不会成为选中页。
typedef NS_ENUM(NSUInteger, XBTabBarItemKind) {
    XBTabBarItemKindPage,   ///< 对应一个子控制器，点击后切换页面；兼容原有配置的默认值。
    XBTabBarItemKindAction, ///< 只触发操作回调，不需要占位控制器，不改变当前页或高亮。
};

/// 横向排列使用语义方向：Leading 在从右向左的语言中位于右侧。
typedef NS_ENUM(NSUInteger, XBTabBarItemLayout) {
    XBTabBarItemLayoutImageAboveTitle, ///< 上图下文，默认布局，保留现有图标及标题位置。
    XBTabBarItemLayoutTitleAboveImage, ///< 上文下图，标题在上、图标在下。
    XBTabBarItemLayoutImageLeading,    ///< 图标在语义起始侧、标题在结束侧，整体居中。
    XBTabBarItemLayoutTitleLeading,    ///< 标题在语义起始侧、图标在结束侧，整体居中。
    XBTabBarItemLayoutImageOnly,       ///< 仅图标，在内容边距限定的区域内居中。
    XBTabBarItemLayoutTitleOnly,       ///< 仅标题，在内容边距限定的区域内居中。
};

/// 点击获准后播放的轻量预设；只改变可见图标（无图标时为文字）的显示，不改变按钮、角标或布局。
typedef NS_ENUM(NSUInteger, XBTabBarItemAnimation) {
    XBTabBarItemAnimationNone,   ///< 不播放预设，默认值；保持已有业务的点击效果。
    XBTabBarItemAnimationScale,  ///< 先轻微缩小，再恢复原尺寸，无弹簧振荡。
    XBTabBarItemAnimationSpring, ///< 从缩小状态弹回原尺寸，带逐渐衰减的弹簧回弹。
    XBTabBarItemAnimationBounce, ///< 向上轻跳并小幅回跳，最终回到原位置。
};

/// 一个按钮的完整样式；全局外观继承此类，单项可通过 style 使用独立副本。
/// 不做逐字段的隐式合并；建议复制当前 tabBarAppearance 再修改需要覆盖的字段。
/// 竖栏自动选择仅图/仅文，并使用对称5pt内容边距；layout/contentInsets 的原配置保留供横栏恢复。
@interface XBTabBarItemStyle : NSObject <NSCopying>
@property (nonatomic, assign) XBTabBarItemLayout layout;
/// 默认 None；单项与全局采用相同规则。自定义 selectionAnimation 回调存在时替代预设，不叠加。
/// 重复点击可重播；程序同步选择、准入拒绝、禁用入口及系统“减少动态效果”不播放。
@property (nonatomic, assign) XBTabBarItemAnimation selectionAnimationType;
/// 图标目标尺寸，默认23×23；不强制拉伸，空间不足时允许缩小。
@property (nonatomic, assign) CGSize imageSize;
/// 图标与标题间距，默认5；仅图/仅文时不保留空占位和间距。
@property (nonatomic, assign) CGFloat imageTitleSpacing;
/// 内容边距默认 top=5、left/right=5、bottom=0，不改变等宽按钮的点击范围。
@property (nonatomic, assign) UIEdgeInsets contentInsets;
/// 实际按钮尺寸；每个0分量沿用槽位宽度/栏按钮区高度。宽度最多为槽位宽，避免覆盖相邻入口。
/// 竖栏使用完整槽位作为点击区域，不应用 buttonSize/raisedHeight，保留配置供横栏恢复。
@property (nonatomic, assign) CGSize buttonSize;
/// 按钮底边相对槽位底边向上抬升的距离，默认0；大尺寸按钮自身也会向上突出，不增加栏高。
@property (nonatomic, assign) CGFloat raisedHeight;
/// 按钮背景圆角，默认0；56×56配28可实现圆形。只裁剪背景，不裁剪角标，点击按圆角轮廓判断。
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, strong) UIFont *titleFont;
/// nil 沿用 titleFont；切换字体不会重建按钮或丢失点击事件。
@property (nonatomic, strong, nullable) UIFont *selectedTitleFont;
@property (nonatomic, strong) UIColor *normalColor;
@property (nonatomic, strong) UIColor *selectedColor;
/// 按钮背景默认透明；选中背景未配置时沿用普通背景，与栏背景分开管理。
@property (nonatomic, strong, nullable) UIColor *normalBackgroundColor;
@property (nonatomic, strong, nullable) UIColor *selectedBackgroundColor;
/// 选中图片未配置时沿用普通背景图；背景图不会参与图文排列或拦截点击。
@property (nonatomic, strong, nullable) UIImage *normalBackgroundImage;
@property (nonatomic, strong, nullable) UIImage *selectedBackgroundImage;
@property (nonatomic, assign) UIViewContentMode backgroundImageContentMode;
@property (nonatomic, strong) UIColor *badgeColor;
@property (nonatomic, strong) UIColor *badgeTextColor;
/// 文字角标高度默认15，红点始终为6。上文下图、图在前文字在后及仅文字跟随文字右上角，
/// 其它普通布局跟随图标，无文字/图标时回退到可见内容；
/// 有可见背景的定制/凸起按钮跟随背景轮廓，圆形约一点半方向。均为视觉内容的物理右上角。
@property (nonatomic, assign) CGFloat badgeHeight;
@end

/// 一个入口的展示配置，不持有控制器、权限或网络请求。identifier 用于重排后恢复选择。
/// 配置交给按钮栏时会复制；后续修改请通过 updateItem: 重新应用。
@interface XBTabBarItem : NSObject <NSCopying>
/// 稳定且在同一栏内唯一，例如 home/profile；不要使用数组下标、会变化的标题或未读数量。
@property (nonatomic, copy, readonly) NSString *identifier;
/// 创建后不可改变类型；需要调整入口结构时使用容器的 setViewControllers:tabBarItems:。
@property (nonatomic, assign, readonly) XBTabBarItemKind kind;
@property (nonatomic, copy) NSString *title;
/// 普通状态的图标；不要只配置 selectedImage，否则未选中时竖栏会回退为标题。
/// 使用模板图时颜色来自 normalColor/selectedColor；AlwaysOriginal 保留图片原色。
@property (nonatomic, strong, nullable) UIImage *image;
/// 未提供选中图时沿用 image；图片本身的 renderingMode 决定是否接受主题 tint。
@property (nonatomic, strong, nullable) UIImage *selectedImage;
/// nil 隐藏；空字符串显示红点；非空字符串原样显示。数字上限及已读规则由业务决定。
@property (nonatomic, copy, nullable) NSString *badgeValue;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
/// nil 跟随栏的全局按钮样式；非 nil 是完整单项样式，不覆盖栏高和栏背景。
/// 设置和交给按钮栏时都会复制；移除覆盖时设为 nil，再调用 updateItem:。
@property (nonatomic, copy, nullable) XBTabBarItemStyle *style;
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title
                            image:(nullable UIImage *)image selectedImage:(nullable UIImage *)selectedImage;
/// kind=Action 时不提供占位控制器，由容器 delegate 接收独立操作。
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title
                            image:(nullable UIImage *)image selectedImage:(nullable UIImage *)selectedImage kind:(XBTabBarItemKind)kind NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// 按钮栏统一外观。默认不含任何项目图片、字体名称、颜色 Token 或屏幕尺寸判断。
/// 修改后重新赋给 appearance 即可更新已有按钮，无需重建控制器。
/// 容器接入示例：XBTabBarAppearance *style = tabs.tabBarAppearance;
/// style.selectedColor = UIColor.systemRedColor; tabs.tabBarAppearance = style;
/// 设置 item.style 后该入口使用完整单项样式，后续全局按钮样式变化不会自动合并到该入口。
@interface XBTabBarAppearance : XBTabBarItemStyle
/// 竖栏宽度默认56，至少44；容器还会限制其不超出可用宽度，不足44时暂时隐藏。
@property (nonatomic, assign) CGFloat floatingWidth;
/// 竖栏每项高度默认44，至少44。竖栏上下各有8pt内边距，至少能完整显示一项才会出现。
@property (nonatomic, assign) CGFloat floatingItemHeight;
/// 胶囊与可用边缘的间距，默认12，负值按0处理；不需要接入方再加系统安全区。
@property (nonatomic, assign) CGFloat floatingMargin;
/// 给宿主侧边导航操作预留的顶部空间，默认112，可按宿主导航调整；不是相机/铰链的尺寸。
/// 容器仍会查询系统保留区域，并在键盘或短窗口下缩小视口、滚动入口。
@property (nonatomic, assign) CGFloat floatingTopClearance;
/// 只表示按钮区高度，不含底部 Home Indicator；默认49，容器负责补上安全区。
@property (nonatomic, assign) CGFloat contentHeight;
/// 无模糊时的底色，也是系统开启“减少透明度”时的实色回退。
@property (nonatomic, strong) UIColor *backgroundColor;
/// 铺满整个底栏及底部安全区；默认无背景图，默认裁剪填充。
@property (nonatomic, strong, nullable) UIImage *backgroundImage;
@property (nonatomic, assign) UIViewContentMode barBackgroundImageContentMode;
/// nil 关闭模糊；使用 UIKit 普通毛玻璃，不代表系统 Liquid Glass。
/// 开启后栏底色透明，以便采样背景图或下方内容；调色请使用 backgroundOverlayColor。
@property (nonatomic, strong, nullable) UIBlurEffect *backgroundBlurEffect;
/// 位于背景图/毛玻璃之上、按钮之下，默认透明；建议使用带透明度的颜色。
@property (nonatomic, strong, nullable) UIColor *backgroundOverlayColor;
@property (nonatomic, strong) UIColor *separatorColor;
/// 横栏顶部分割线默认0.5，设置0隐藏；竖栏不显示此分割线。
@property (nonatomic, assign) CGFloat separatorHeight;
@end

NS_ASSUME_NONNULL_END
