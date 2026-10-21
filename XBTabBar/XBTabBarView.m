#import "XBTabBarView.h"
#import <Masonry/Masonry.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

/// 只替换/移除组件自己的动画，不清空业务可能附加到同一图标的其它动画。
static NSString * const XBTabBarSelectionAnimationKey = @"XBTabBar.selection";

/// 背景按视图边缘铺满，不让 SF Symbols 等图片自带的对齐内边距在四周留下细缝。
@interface XBTabBarBackgroundImageView : UIImageView
@end
@implementation XBTabBarBackgroundImageView
- (UIEdgeInsets)alignmentRectInsets {
    return UIEdgeInsetsZero;
}
@end

/// 私有展示控件；业务不直接操作内部 UILabel/UIImageView，避免状态同时由多处维护。
@interface XBTabBarButton : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) XBTabBarItem *item;
/// 图文组合保留同一组控件，布局/状态切换不替换图标，外部动画仍附着在原视图上。
@property (nonatomic, strong) UIStackView *contentStack;
/// 仅配置了单项背景图时创建，不让普通按钮承担额外图片渲染成本。
@property (nonatomic, strong) UIImageView *backgroundImageView;
/// 圆角轮廓同时用于背景与命中；不对整个按钮 masksToBounds，保证右上角角标完整显示。
@property (nonatomic, assign) CGFloat configuredCornerRadius;
/// 仅有背景的定制按钮需要此几何锚点；用约束计算圆角45度位置，窗口变化时无需手工重算 frame。
@property (nonatomic, strong) UIView *badgeCornerAnchor;
- (void)applyAppearance:(XBTabBarAppearance *)appearance selected:(BOOL)selected;
- (void)stopSelectionAnimation;
- (void)animateSelectionWithType:(XBTabBarItemAnimation)type;
@end

@implementation XBTabBarButton
/// 禁止图片和文本截获事件，让整个等宽入口都是同一个可访问、可点击的控件。
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.isAccessibilityElement = YES;
        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _textLabel = [UILabel new];
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.numberOfLines = 1;
        _textLabel.adjustsFontSizeToFitWidth = YES;
        _textLabel.minimumScaleFactor = 0.8;
        _badgeLabel = [UILabel new];
        _badgeLabel.font = [UIFont boldSystemFontOfSize:10];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.clipsToBounds = YES;
        _badgeLabel.adjustsFontSizeToFitWidth = YES;
        _badgeLabel.minimumScaleFactor = 0.7;
        _contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _textLabel]];
        _contentStack.userInteractionEnabled = NO;
        [self addSubview:_contentStack];
        [self addSubview:_badgeLabel];
    }
    return self;
}
/// StackView 会缓存排列方向；运行时切换 RTL 时显式同步，不能只修改外层按钮。
- (void)setSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute {
    [super setSemanticContentAttribute:semanticContentAttribute];
    self.contentStack.semanticContentAttribute = semanticContentAttribute;
    [self.contentStack setNeedsLayout];
}
/// 统一应用展示状态；角标使用配置值，不自行把0解释为未读或修改业务数据。
- (void)applyAppearance:(XBTabBarAppearance *)appearance selected:(BOOL)selected {
    XBTabBarItemStyle *style = self.item.style ?: appearance;
    self.selected = selected;
    self.configuredCornerRadius = MAX(0, style.cornerRadius);
    [self setNeedsLayout];
    self.enabled = self.item.isEnabled;
    self.alpha = self.enabled ? 1 : 0.4;
    self.iconView.image = selected ? (self.item.selectedImage ?: self.item.image) : self.item.image;
    self.iconView.tintColor = selected ? style.selectedColor : style.normalColor;
    self.textLabel.text = self.item.title;
    self.textLabel.font = selected ? (style.selectedTitleFont ?: style.titleFont) : style.titleFont;
    self.textLabel.textColor = self.iconView.tintColor;
    self.backgroundColor = selected ? (style.selectedBackgroundColor ?: style.normalBackgroundColor) : style.normalBackgroundColor;
    UIImage *backgroundImage = selected ? (style.selectedBackgroundImage ?: style.normalBackgroundImage) : style.normalBackgroundImage;
    [self applyBackgroundImage:backgroundImage contentMode:style.backgroundImageContentMode];
    [self applyContentLayout:style];
    if (style.selectionAnimationType == XBTabBarItemAnimationNone || !self.enabled) {
        [self stopSelectionAnimation];
    } else {
        // 布局切换为仅图/仅文时，不让隐藏内容在再次显示后带着旧动画。
        if (self.iconView.hidden) {
            [self.iconView.layer removeAnimationForKey:XBTabBarSelectionAnimationKey];
        }
        if (self.textLabel.hidden) {
            [self.textLabel.layer removeAnimationForKey:XBTabBarSelectionAnimationKey];
        }
    }
    [self applyBadgeWithStyle:style];
    self.accessibilityLabel = self.item.title;
    self.accessibilityValue = self.item.badgeValue.length > 0 ? self.item.badgeValue : nil;
    self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0) | (self.enabled ? 0 : UIAccessibilityTraitNotEnabled);
}

/// 不修改模型层 transform，也不使用完成回调；中断、重播或移除按钮都不会残留缩放/位移。
- (void)stopSelectionAnimation {
    [self.iconView.layer removeAnimationForKey:XBTabBarSelectionAnimationKey];
    [self.textLabel.layer removeAnimationForKey:XBTabBarSelectionAnimationKey];
}

/// 同一键替换上次点击效果，快速连点不排队；背景、角标与 UIControl 命中区域保持静止。
- (void)animateSelectionWithType:(XBTabBarItemAnimation)type {
    [self stopSelectionAnimation];
    UIView *target = nil;
    if (!self.iconView.hidden) {
        target = self.iconView;
    } else if (!self.textLabel.hidden) {
        target = self.textLabel;
    } else {
        return;
    }
    CAAnimation *animation = nil;
    switch (type) {
        case XBTabBarItemAnimationNone:
            return;
        case XBTabBarItemAnimationScale: {
            CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            scale.values = @[@1, @0.82, @1];
            scale.keyTimes = @[@0, @0.4, @1];
            scale.duration = 0.24;
            scale.calculationMode = kCAAnimationCubic;
            animation = scale;
            break;
        }
        case XBTabBarItemAnimationSpring: {
            CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:@"transform.scale"];
            spring.fromValue = @0.72;
            spring.toValue = @1;
            spring.mass = 1;
            spring.stiffness = 240;
            spring.damping = 14;
            spring.initialVelocity = 0;
            spring.duration = spring.settlingDuration;
            animation = spring;
            break;
        }
        case XBTabBarItemAnimationBounce: {
            CAKeyframeAnimation *bounce = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
            bounce.values = @[@0, @(-6), @0, @(-2), @0];
            bounce.keyTimes = @[@0, @0.3, @0.6, @0.8, @1];
            bounce.duration = 0.38;
            bounce.calculationMode = kCAAnimationCubic;
            bounce.additive = YES;
            animation = bounce;
            break;
        }
        default:
            return;
    }
    [target.layer addAnimation:animation forKey:XBTabBarSelectionAnimationKey];
}

/// 普通入口标记图标/文字而不是等宽点击槽位；有可见背景的定制按钮才沿背景轮廓定位。
- (void)applyBadgeWithStyle:(XBTabBarItemStyle *)style {
    self.badgeLabel.backgroundColor = style.badgeColor;
    self.badgeLabel.textColor = style.badgeTextColor;
    self.badgeLabel.text = self.item.badgeValue;
    self.badgeLabel.hidden = self.item.badgeValue == nil;
    if (self.badgeLabel.hidden) {
        return;
    }
    BOOL dot = self.item.badgeValue.length == 0;
    CGFloat height = dot ? 6 : MAX(0, style.badgeHeight);
    CGFloat width = dot ? 6 : MAX(height, [self.badgeLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, height)].width + 6);
    self.badgeLabel.layer.cornerRadius = height / 2;
    BOOL customizedButton = style.raisedHeight > 0 || style.buttonSize.width > 0 || style.buttonSize.height > 0 || style.cornerRadius > 0;
    UIColor *background = [self.backgroundColor resolvedColorWithTraitCollection:self.traitCollection];
    BOOL visibleBackground = self.backgroundImageView.image != nil || (background != nil && CGColorGetAlpha(background.CGColor) > 0.01);
    BOOL followsOutline = customizedButton && visibleBackground;
    if (followsOutline) {
        if (self.badgeCornerAnchor == nil) {
            self.badgeCornerAnchor = [UIView new];
            self.badgeCornerAnchor.hidden = YES;
            self.badgeCornerAnchor.userInteractionEnabled = NO;
            [self insertSubview:self.badgeCornerAnchor atIndex:0];
        }
        // 圆角右上弧45度处距两边均为 r*(1-sqrt(0.5))；r 同时受宽/高的一半约束，与背景圆角一致。
        CGFloat projection = 1 - sqrt(0.5);
        [self.badgeCornerAnchor mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.right.equalTo(self);
            make.width.mas_equalTo(self.configuredCornerRadius * projection).priority(999);
            make.width.lessThanOrEqualTo(self.mas_width).multipliedBy(projection / 2);
            make.width.lessThanOrEqualTo(self.mas_height).multipliedBy(projection / 2);
            make.height.equalTo(self.badgeCornerAnchor.mas_width);
        }];
    }
    // 上文下图、图在前文字在后以文字为主；文字缺失时回退图标，其它布局保持原规则。
    BOOL titleLayout = style.layout == XBTabBarItemLayoutTitleAboveImage || style.layout == XBTabBarItemLayoutImageLeading;
    BOOL anchorsTitle = !self.textLabel.hidden && (self.iconView.hidden || titleLayout);
    UIView *anchor = anchorsTitle ? self.textLabel : self.iconView;
    UIView *boundary = self.superview ?: self;
    BOOL horizontalPair = self.contentStack.axis == UILayoutConstraintAxisHorizontal && !self.iconView.hidden && !self.textLabel.hidden;
    [self.badgeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (followsOutline) {
            make.centerX.equalTo(self.badgeCornerAnchor.mas_left).priority(249);
            make.centerY.equalTo(self.badgeCornerAnchor.mas_bottom);
        } else {
            // 数字向右增长，只轻压图标边缘；以文字为锚点时留2点间隔，不盖住最后一个字。
            make.left.equalTo(anchor.mas_right).offset(anchorsTitle ? 2 : -3).priority(249);
            if (horizontalPair) {
                // 只确定一个纵向锚点，让角标随标题顶部上移，不用竞争约束把标题高度压缩。
                make.bottom.equalTo(self.textLabel.mas_top).offset(-1);
            } else {
                make.centerY.equalTo(anchor.mas_top).offset(2).priority(249);
            }
        }
        // 在槽位内限制长角标，不侵入相邻入口；先保住最小圆形，再允许文字缩小/截断。
        make.left.greaterThanOrEqualTo(boundary.mas_left).offset(2);
        make.right.lessThanOrEqualTo(boundary.mas_right).offset(-2);
        // 保留角标文字内边距，但低于标题的抗压缩优先级；优先移动角标，不把标题挤成省略号。
        make.width.mas_equalTo(width).priority(749);
        make.width.greaterThanOrEqualTo(@(height)).priority(999);
        make.height.mas_equalTo(height);
    }];
}

/// 圆角按实际布局尺寸收敛，背景图与底色共用轮廓；角标独立绘制，不被圆角裁剪。
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat radius = MIN(self.configuredCornerRadius, MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) / 2);
    self.layer.cornerRadius = radius;
    self.backgroundImageView.layer.cornerRadius = radius;
}

/// 圆形按钮四个透明角不抢走下方页面的手势；普通按钮仍使用完整矩形点击区。
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (![super pointInside:point withEvent:event]) {
        return NO;
    }
    CGFloat radius = MIN(self.configuredCornerRadius, MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) / 2);
    if (radius > 0) {
        return [[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius] containsPoint:point];
    }
    return YES;
}

/// 背景始终在图文与角标下方，切换回无背景时清空图片，避免旧资源继续被持有。
- (void)applyBackgroundImage:(UIImage *)image contentMode:(UIViewContentMode)contentMode {
    if (image != nil && self.backgroundImageView == nil) {
        self.backgroundImageView = [XBTabBarBackgroundImageView new];
        self.backgroundImageView.clipsToBounds = YES;
        [self insertSubview:self.backgroundImageView atIndex:0];
        [self.backgroundImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    self.backgroundImageView.image = image;
    self.backgroundImageView.contentMode = contentMode;
    self.backgroundImageView.hidden = image == nil;
}

/// 图文缺一时不保留空占位；纵向双内容保持原顶部图标/剩余标题区，横向和单内容整体居中。
- (void)applyContentLayout:(XBTabBarItemStyle *)style {
    BOOL showsImage = style.layout != XBTabBarItemLayoutTitleOnly && self.iconView.image != nil;
    BOOL showsTitle = style.layout != XBTabBarItemLayoutImageOnly && self.item.title.length > 0;
    BOOL horizontal = style.layout == XBTabBarItemLayoutImageLeading || style.layout == XBTabBarItemLayoutTitleLeading;
    BOOL titleFirst = style.layout == XBTabBarItemLayoutTitleAboveImage || style.layout == XBTabBarItemLayoutTitleLeading;
    UIView *first = titleFirst ? self.textLabel : self.iconView;
    UIView *last = titleFirst ? self.iconView : self.textLabel;
    if (self.contentStack.arrangedSubviews.firstObject != first) {
        [self.contentStack removeArrangedSubview:first];
        [self.contentStack removeArrangedSubview:last];
        [self.contentStack addArrangedSubview:first];
        [self.contentStack addArrangedSubview:last];
    }
    self.iconView.hidden = !showsImage;
    self.textLabel.hidden = !showsTitle;
    self.contentStack.axis = horizontal ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentCenter;
    self.contentStack.spacing = MAX(0, style.imageTitleSpacing);
    UIEdgeInsets insets = style.contentInsets;
    BOOL fillsVerticalArea = !horizontal && showsImage && showsTitle;
    [self.contentStack mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (fillsVerticalArea) {
            make.top.equalTo(self).offset(insets.top);
            make.bottom.equalTo(self).offset(-insets.bottom);
            make.left.equalTo(self).offset(insets.left);
            make.right.equalTo(self).offset(-insets.right);
        } else {
            make.centerX.equalTo(self).offset((insets.left - insets.right) / 2);
            make.centerY.equalTo(self).offset((insets.top - insets.bottom) / 2);
            make.left.greaterThanOrEqualTo(self).offset(insets.left);
            make.right.lessThanOrEqualTo(self).offset(-insets.right);
            make.top.greaterThanOrEqualTo(self).offset(insets.top);
            make.bottom.lessThanOrEqualTo(self).offset(-insets.bottom);
        }
    }];
    [self.iconView mas_remakeConstraints:^(MASConstraintMaker *make) {
        // UIStackView 隐藏内容时会施加零尺寸；目标尺寸用999，避免与系统隐藏约束冲突。
        make.width.mas_equalTo(MAX(0, style.imageSize.width)).priority(999);
        make.height.mas_equalTo(MAX(0, style.imageSize.height)).priority(999);
        make.width.lessThanOrEqualTo(self).offset(-insets.left - insets.right);
        make.height.lessThanOrEqualTo(self).offset(-insets.top - insets.bottom);
    }];
    [self.textLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (fillsVerticalArea) {
            // 标题按文案固有宽度居中，长文案才受内容区限制；角标不会被拉满整列的 UILabel 带远。
            make.width.lessThanOrEqualTo(self.contentStack);
        }
    }];
}
@end

@interface XBTabBarView ()
@property (nonatomic, strong) NSMutableArray<XBTabBarButton *> *buttons;
/// 每个入口保留一个等宽槽位，实际按钮可在槽位内缩小、增高或上移，不影响其它入口下标。
@property (nonatomic, strong) NSMutableArray<UIView *> *itemSlots;
@property (nonatomic, strong) UIView *buttonArea;
@property (nonatomic, strong) UIView *separator;
/// 按需创建的背景层，顺序固定为背景图 → 毛玻璃 → 调色遮罩 → 分割线 → 按钮。
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *backgroundOverlayView;
@end

@implementation XBTabBarView
@synthesize items = _items;
@synthesize appearance = _appearance;
/// 初始化只创建显示宿主，不访问 UIApplication、PCH、屏幕型号或全局主题。
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self xb_initializeBar];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self xb_initializeBar];
    }
    return self;
}

/// XIB 解码和代码创建保持相同的配置及观察者状态。
- (void)xb_initializeBar {
    if (_buttons != nil) {
        return;
    }
    _items = @[];
    _buttons = [NSMutableArray array];
    _itemSlots = [NSMutableArray array];
    _selectedIndex = NSNotFound;
    _appearance = [XBTabBarAppearance new];
    _buttonArea = [UIView new];
    _separator = [UIView new];
    [self addSubview:_separator];
    [self addSubview:_buttonArea];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reduceTransparencyDidChange:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reduceMotionDidChange:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [self applyAppearance];
}

/// 公开读取返回深复制快照，内部按钮与配置不会被绕过 updateItem: 修改。
- (NSArray<XBTabBarItem *> *)items {
    return [[NSArray alloc] initWithArray:_items copyItems:YES];
}

- (XBTabBarAppearance *)appearance {
    return [_appearance copy];
}

/// 先校验配置再替换，避免重复标识导致选择恢复、角标更新到错误入口。
- (void)setItems:(NSArray<XBTabBarItem *> *)items {
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (XBTabBarItem *item in items) {
        BOOL valid = item.identifier.length > 0 && ![identifiers containsObject:item.identifier] &&
            (item.kind == XBTabBarItemKindPage || item.kind == XBTabBarItemKindAction);
        NSAssert(valid, @"Tab identifiers must be nonempty and unique");
        if (!valid) {
            return;
        }
        [identifiers addObject:item.identifier];
    }
    NSString *selectedIdentifier = self.selectedIndex < _items.count ? _items[self.selectedIndex].identifier : nil;
    for (UIView *slot in self.itemSlots) {
        [slot removeFromSuperview];
    }
    [self.buttons removeAllObjects];
    [self.itemSlots removeAllObjects];
    _items = [[NSArray alloc] initWithArray:items copyItems:YES];
    _selectedIndex = NSNotFound;
    for (XBTabBarItem *item in _items) {
        XBTabBarButton *button = [XBTabBarButton new];
        button.semanticContentAttribute = self.semanticContentAttribute;
        button.item = item;
        [button addTarget:self action:@selector(handleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        UIView *slot = [UIView new];
        [self.buttonArea addSubview:slot];
        [slot addSubview:button];
        [self.itemSlots addObject:slot];
        if (item.kind == XBTabBarItemKindPage && [selectedIdentifier isEqualToString:item.identifier]) {
            _selectedIndex = self.buttons.count;
        } else if (_selectedIndex == NSNotFound && item.kind == XBTabBarItemKindPage) {
            _selectedIndex = self.buttons.count;
        }
        [self.buttons addObject:button];
    }
    // 等宽只依赖宿主约束，窗口变化无需读取 UIScreen 或手动重算每个按钮的 frame。
    UIView *previous = nil;
    for (UIView *slot in self.itemSlots) {
        [slot mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self.buttonArea);
            if (previous != nil) {
                make.leading.equalTo(previous.mas_trailing);
                make.width.equalTo(previous);
            } else {
                make.leading.equalTo(self.buttonArea);
            }
            if (slot == self.itemSlots.lastObject) {
                make.trailing.equalTo(self.buttonArea);
            }
        }];
        previous = slot;
    }
    [self applyAppearance];
}
/// 只渲染状态，绝不调用点击回调，因此路由和页面恢复不会误触刷新或权限请求。
- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    if (selectedIndex != NSNotFound && (selectedIndex >= _items.count || _items[selectedIndex].kind != XBTabBarItemKindPage)) {
        return;
    }
    _selectedIndex = selectedIndex;
    [self refreshButtons];
}
/// 外观作为值保存；对非正高度使用默认值，避免按钮区因错误配置变为不可点。
- (void)setAppearance:(XBTabBarAppearance *)appearance {
    _appearance = [appearance copy];
    if (_appearance.contentHeight <= 0) {
        _appearance.contentHeight = 49;
    }
    [self applyAppearance];
}

/// 接入方运行时切换语言方向时，把显式方向传给约束两端，避免内部控件仍沿用旧的布局方向。
- (void)setSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute {
    [super setSemanticContentAttribute:semanticContentAttribute];
    self.buttonArea.semanticContentAttribute = semanticContentAttribute;
    for (XBTabBarButton *button in self.buttons) {
        button.semanticContentAttribute = semanticContentAttribute;
    }
    [self.buttonArea setNeedsLayout];
    [self setNeedsLayout];
}

/// 背景覆盖底部安全区，但按钮只占用 contentHeight；分割线由本视图统一维护。
- (void)applyAppearance {
    [self applyBackground];
    self.separator.backgroundColor = _appearance.separatorColor;
    [self.buttonArea mas_remakeConstraints:^(MASConstraintMaker *make) {
        // 背景仍铺满窗口，交互按钮避开侧边系统栏/摄像头；不把左右安全区强制减为0。
        make.left.equalTo(self.mas_safeAreaLayoutGuideLeft);
        make.right.equalTo(self.mas_safeAreaLayoutGuideRight);
        make.top.equalTo(self);
        make.height.mas_equalTo(_appearance.contentHeight);
    }];
    [self.separator mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.equalTo(self);
        make.height.mas_equalTo(MAX(0, _appearance.separatorHeight));
    }];
    [self refreshButtons];
}

/// 不开启时不创建模糊视图；背景铺满底部安全区，但不影响按钮布局与命中区域。
- (void)applyBackground {
    XBTabBarAppearance *appearance = _appearance;
    BOOL blursBackground = appearance.backgroundBlurEffect != nil && !UIAccessibilityIsReduceTransparencyEnabled();
    self.backgroundColor = blursBackground ? UIColor.clearColor : appearance.backgroundColor;
    self.opaque = NO;
    if (appearance.backgroundImage != nil && self.backgroundImageView == nil) {
        self.backgroundImageView = [XBTabBarBackgroundImageView new];
        self.backgroundImageView.clipsToBounds = YES;
        [self insertSubview:self.backgroundImageView atIndex:0];
        [self.backgroundImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    self.backgroundImageView.image = appearance.backgroundImage;
    self.backgroundImageView.contentMode = appearance.barBackgroundImageContentMode;
    self.backgroundImageView.hidden = appearance.backgroundImage == nil;
    if (blursBackground && self.blurView == nil) {
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
        self.blurView.userInteractionEnabled = NO;
        [self insertSubview:self.blurView belowSubview:self.buttonArea];
        [self.blurView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    self.blurView.effect = blursBackground ? appearance.backgroundBlurEffect : nil;
    self.blurView.hidden = !blursBackground;
    if (appearance.backgroundOverlayColor != nil && self.backgroundOverlayView == nil) {
        self.backgroundOverlayView = [UIView new];
        self.backgroundOverlayView.userInteractionEnabled = NO;
        [self insertSubview:self.backgroundOverlayView belowSubview:self.buttonArea];
        [self.backgroundOverlayView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    // 先有遮罩、后开启毛玻璃时也保持相同顺序，不能让模糊层盖在调色层上。
    if (self.backgroundOverlayView != nil) {
        [self insertSubview:self.backgroundOverlayView belowSubview:self.buttonArea];
    }
    self.backgroundOverlayView.backgroundColor = appearance.backgroundOverlayColor;
    self.backgroundOverlayView.hidden = appearance.backgroundOverlayColor == nil;
    // 偏好通知也会单独更新背景，统一在这里确保分割线在遮罩之上、凸起按钮之下。
    [self insertSubview:self.separator belowSubview:self.buttonArea];
}

/// 系统透明度偏好改变时只更新背景；不切换页面、不重建按钮，也不重新播放动画。
- (void)reduceTransparencyDidChange:(NSNotification *)notification {
    [self applyBackground];
}

/// 注销本实例监听，不影响同一窗口内其它按钮栏的背景偏好更新。
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
}
/// 系统中途开启“减少动态效果”时立即停止预设，只移除组件动画，不接管业务自定义动画。
- (void)reduceMotionDidChange:(NSNotification *)notification {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (XBTabBarButton *button in self.buttons) {
            [button stopSelectionAnimation];
        }
    }
}
/// 状态更新只触及已有按钮，不替换点击对象；外部动画层可以继续附着在图标上。
- (void)refreshButtons {
    for (NSUInteger index = 0; index < self.buttons.count; index++) {
        [self applyItemAtIndex:index];
    }
}

/// 点击槽位等宽不变；默认按钮铺满槽位，定制按钮沿槽位底边上移，不进入 Home Indicator 区域。
- (void)applyItemAtIndex:(NSUInteger)index {
    XBTabBarButton *button = self.buttons[index];
    XBTabBarItemStyle *style = button.item.style ?: _appearance;
    UIView *slot = self.itemSlots[index];
    [button mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(slot);
        make.bottom.equalTo(slot).offset(-MAX(0, style.raisedHeight));
        if (style.buttonSize.width > 0) {
            make.width.mas_equalTo(style.buttonSize.width).priority(999);
            make.width.lessThanOrEqualTo(slot);
        } else {
            make.width.equalTo(slot);
        }
        make.height.mas_equalTo(style.buttonSize.height > 0 ? style.buttonSize.height : _appearance.contentHeight);
    }];
    [button applyAppearance:_appearance selected:index == self.selectedIndex && button.item.kind == XBTabBarItemKindPage];
}

/// 只扩展真实可点击按钮的区域，不把栏上方的整条页面内容变成底栏点击区。
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if ([super pointInside:point withEvent:event]) {
        return YES;
    }
    return [self buttonAtPoint:point event:event] != nil;
}

/// 直接命中实际按钮，绕过中间槽位/按钮区的边界限制；隐藏、禁用及圆形透明角不会截获越界触摸。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha <= 0.01 || !self.userInteractionEnabled) {
        return nil;
    }
    XBTabBarButton *button = [self buttonAtPoint:point event:event];
    if (button != nil) {
        return button;
    }
    return [super hitTest:point withEvent:event];
}

/// 按与绘制相同的逆序查找，使用坐标转换，兼容窗口变化和底栏转场位移。
- (XBTabBarButton *)buttonAtPoint:(CGPoint)point event:(UIEvent *)event {
    for (XBTabBarButton *button in self.buttons.reverseObjectEnumerator) {
        if (!button.hidden && button.alpha > 0.01 && button.isEnabled && button.userInteractionEnabled &&
            [button pointInside:[button convertPoint:point fromView:self] withEvent:event]) {
            return button;
        }
    }
    return nil;
}
/// 保留重复点击事件，但把是否切换、是否刷新交给容器或独立使用者决定。
- (void)handleButtonTap:(XBTabBarButton *)button {
    NSUInteger index = [self.buttons indexOfObjectIdenticalTo:button];
    if (index != NSNotFound && self.itemTapHandler != nil) {
        self.itemTapHandler(button.item.identifier, index);
    }
}
/// 查询返回副本，修改后需显式 updateItem，防止业务绕过渲染更新内部配置。
- (XBTabBarItem *)itemForIdentifier:(NSString *)identifier {
    for (XBTabBarItem *item in _items) {
        if ([item.identifier isEqualToString:identifier]) {
            return [item copy];
        }
    }
    return nil;
}
/// 按标识替换单项，数组顺序和当前选中位置保持不变。
- (void)updateItem:(XBTabBarItem *)item {
    NSUInteger index = [_items indexOfObjectPassingTest:^BOOL(XBTabBarItem *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.identifier isEqualToString:item.identifier];
    }];
    if (index == NSNotFound) {
        return;
    }
    BOOL sameKind = _items[index].kind == item.kind;
    NSAssert(sameKind, @"Changing item kind requires rebuilding controllers and tabBarItems together");
    if (!sameKind) {
        return;
    }
    NSMutableArray *items = [_items mutableCopy];
    XBTabBarItem *updated = [item copy];
    items[index] = updated;
    _items = [items copy];
    self.buttons[index].item = updated;
    [self applyItemAtIndex:index];
}
/// 角标更新复用单项更新路径，不要求业务获取内部 UILabel。
- (void)setBadgeValue:(NSString *)value forIdentifier:(NSString *)identifier {
    XBTabBarItem *item = [self itemForIdentifier:identifier];
    if (item != nil) {
        item.badgeValue = value;
        [self updateItem:item];
    }
}
/// 与点击准入共用原入口：自定义回调优先，否则使用单项/全局预设；不把动画混入布局和数据更新。
- (void)animateSelectionAtIndex:(NSUInteger)index reselected:(BOOL)reselected {
    if (index >= self.buttons.count) {
        return;
    }
    XBTabBarButton *button = self.buttons[index];
    if (!button.enabled || UIAccessibilityIsReduceMotionEnabled() || !UIView.areAnimationsEnabled) {
        [button stopSelectionAnimation];
        return;
    }
    if (self.selectionAnimation != nil) {
        [button stopSelectionAnimation];
        self.selectionAnimation(button.iconView, reselected);
    } else {
        XBTabBarItemStyle *style = button.item.style ?: _appearance;
        [button animateSelectionWithType:style.selectionAnimationType];
    }
}
@end
