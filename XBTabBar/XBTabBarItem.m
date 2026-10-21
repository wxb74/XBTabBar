#import "XBTabBarItem.h"

@implementation XBTabBarItem
/// identifier 是入口身份，不使用可能变为“刷新”的标题作为身份。
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage {
    return [self initWithIdentifier:identifier title:title image:image selectedImage:selectedImage kind:XBTabBarItemKindPage];
}
/// 操作入口只携带展示数据，不持有业务 block 或控制器，避免配置形成引用环。
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage kind:(XBTabBarItemKind)kind {
    NSParameterAssert(identifier.length > 0);
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _kind = kind;
        _title = [title copy];
        _image = image;
        _selectedImage = selectedImage;
        _enabled = YES;
    }
    return self;
}
/// 隔离调用方配置的后续修改，避免未显式刷新就改变按钮栏的内部数据。
- (id)copyWithZone:(NSZone *)zone {
    XBTabBarItem *item = [[[self class] allocWithZone:zone] initWithIdentifier:self.identifier title:self.title image:self.image selectedImage:self.selectedImage kind:self.kind];
    item.badgeValue = self.badgeValue;
    item.enabled = self.enabled;
    item.style = self.style;
    return item;
}
@end

@implementation XBTabBarItemStyle
/// 系统语义色随浅色/深色自动解析；不依赖 App 的主题管理器。
- (instancetype)init {
    self = [super init];
    if (self) {
        _layout = XBTabBarItemLayoutImageAboveTitle;
        _selectionAnimationType = XBTabBarItemAnimationNone;
        _imageSize = CGSizeMake(23, 23);
        _imageTitleSpacing = 5;
        _contentInsets = UIEdgeInsetsMake(5, 5, 0, 5);
        _titleFont = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _normalColor = UIColor.secondaryLabelColor;
        _selectedColor = UIColor.systemBlueColor;
        _backgroundImageContentMode = UIViewContentModeScaleAspectFill;
        _badgeColor = UIColor.systemRedColor;
        _badgeTextColor = UIColor.whiteColor;
        _badgeHeight = 15;
    }
    return self;
}
/// 外观也是值配置；两个容器可以共用初始配置而不会互相改变运行中的外观。
- (id)copyWithZone:(NSZone *)zone {
    XBTabBarItemStyle *appearance = [[[self class] allocWithZone:zone] init];
    appearance.layout = self.layout;
    appearance.selectionAnimationType = self.selectionAnimationType;
    appearance.imageSize = self.imageSize;
    appearance.imageTitleSpacing = self.imageTitleSpacing;
    appearance.contentInsets = self.contentInsets;
    appearance.buttonSize = self.buttonSize;
    appearance.raisedHeight = self.raisedHeight;
    appearance.cornerRadius = self.cornerRadius;
    appearance.titleFont = self.titleFont;
    appearance.selectedTitleFont = self.selectedTitleFont;
    appearance.normalColor = self.normalColor;
    appearance.selectedColor = self.selectedColor;
    appearance.normalBackgroundColor = self.normalBackgroundColor;
    appearance.selectedBackgroundColor = self.selectedBackgroundColor;
    appearance.normalBackgroundImage = self.normalBackgroundImage;
    appearance.selectedBackgroundImage = self.selectedBackgroundImage;
    appearance.backgroundImageContentMode = self.backgroundImageContentMode;
    appearance.badgeColor = self.badgeColor;
    appearance.badgeTextColor = self.badgeTextColor;
    appearance.badgeHeight = self.badgeHeight;
    return appearance;
}
@end

@implementation XBTabBarAppearance
/// 栏级背景与按钮样式独立，默认仍是原有49点纯色栏，不创建模糊层。
- (instancetype)init {
    self = [super init];
    if (self) {
        _contentHeight = 49;
        _backgroundColor = UIColor.systemBackgroundColor;
        _barBackgroundImageContentMode = UIViewContentModeScaleAspectFill;
        _separatorColor = UIColor.separatorColor;
        _separatorHeight = 0.5;
    }
    return self;
}
/// 先复制通用按钮样式，再复制栏背景；跨容器复用配置不会共享可变外观对象。
- (id)copyWithZone:(NSZone *)zone {
    XBTabBarAppearance *appearance = [super copyWithZone:zone];
    appearance.contentHeight = self.contentHeight;
    appearance.backgroundColor = self.backgroundColor;
    appearance.backgroundImage = self.backgroundImage;
    appearance.barBackgroundImageContentMode = self.barBackgroundImageContentMode;
    appearance.backgroundBlurEffect = self.backgroundBlurEffect;
    appearance.backgroundOverlayColor = self.backgroundOverlayColor;
    appearance.separatorColor = self.separatorColor;
    appearance.separatorHeight = self.separatorHeight;
    return appearance;
}
@end
