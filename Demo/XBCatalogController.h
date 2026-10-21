#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface XBCatalogController : UITableViewController
+ (NSArray<NSDictionary *> *)exampleSections;
+ (UIViewController *)exampleWithIdentifier:(NSString *)identifier;
@end
NS_ASSUME_NONNULL_END
