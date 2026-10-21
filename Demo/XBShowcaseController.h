#import "XBTabContainerViewController.h"
NS_ASSUME_NONNULL_BEGIN
@interface XBShowcaseController : XBTabContainerViewController
- (instancetype)initWithExampleIdentifier:(NSString *)identifier;
@end
/// 没有页面容器的独立按钮栏示例。
UIViewController *XBMakeStandaloneExample(void);
/// 同一页面内两个独立容器的示例。
UIViewController *XBMakeMultipleContainersExample(void);
/// XIB 解码入口与 Swift 实际创建入口的示例。
UIViewController *XBMakeInitializationExample(void);
NS_ASSUME_NONNULL_END
