#import <XCTest/XCTest.h>
#import "XBCatalogController.h"
#import "XBShowcaseController.h"

@interface XBShowcaseController (Testing)
- (NSArray<NSDictionary *> *)controls;
- (void)performAction:(NSString *)action;
@end

@interface XBDemoCatalogTests : XCTestCase
@end
@implementation XBDemoCatalogTests
- (void)testAllCatalogEntriesHaveUniqueIdentifiersAndLoad {
    NSMutableSet *identifiers = [NSMutableSet set];
    for (NSDictionary *section in XBCatalogController.exampleSections) {
        XCTAssertTrue([section[@"title"] length] > 0);
        for (NSDictionary *entry in section[@"rows"]) {
            XCTAssertFalse([identifiers containsObject:entry[@"id"]]); [identifiers addObject:entry[@"id"]];
            XCTAssertNotNil([UIImage systemImageNamed:entry[@"symbol"]]);
            UIViewController *example = [XBCatalogController exampleWithIdentifier:entry[@"id"]];
            XCTAssertNotNil(example); [example loadViewIfNeeded];
            example.view.frame = CGRectMake(0, 0, 390, 844); [example.view layoutIfNeeded];
            if ([example isKindOfClass:XBTabContainerViewController.class]) XCTAssertTrue(((XBTabContainerViewController *)example).tabBar.items.count > 0);
        }
    }
    XCTAssertEqual(identifiers.count, 18u);
}
- (void)testEveryShowcaseControlHasAnExecutablePath {
    BOOL animations = UIView.areAnimationsEnabled; [UIView setAnimationsEnabled:NO];
    @try {
        for (NSDictionary *section in XBCatalogController.exampleSections) for (NSDictionary *entry in section[@"rows"]) {
            UIViewController *candidate = [XBCatalogController exampleWithIdentifier:entry[@"id"]];
            if (![candidate isKindOfClass:XBShowcaseController.class]) continue;
            [candidate loadViewIfNeeded];
            for (NSDictionary *control in ((XBShowcaseController *)candidate).controls) {
                XBShowcaseController *example = (id)[XBCatalogController exampleWithIdentifier:entry[@"id"]];
                [example loadViewIfNeeded]; example.view.frame = CGRectMake(0, 0, 390, 844);
                [example performAction:control[@"action"]]; [example.view layoutIfNeeded];
                if ([control[@"action"] isEqualToString:@"empty"] || [control[@"action"] isEqualToString:@"actionsOnly"]) {
                    XCTAssertEqual(example.viewControllers.count, 0u);
                    [example performAction:@"restore"]; XCTAssertEqual(example.viewControllers.count, 3u);
                } else XCTAssertTrue(example.viewControllers.count > 0);
            }
        }
    } @finally { [UIView setAnimationsEnabled:animations]; }
}
- (void)testSelectionExampleDistinguishesRejectionSilentSelectionAndCallbacks {
    XBShowcaseController *example = (id)[XBCatalogController exampleWithIdentifier:@"selection"]; [example loadViewIfNeeded];
    XCTAssertFalse([example selectTabWithIdentifier:@"page.2"]); XCTAssertEqual(example.selectedIndex, 0u);
    [example performAction:@"silentIndex"]; XCTAssertEqual(example.selectedIndex, 2u);
    [example performAction:@"silentObject"]; XCTAssertEqual(example.selectedIndex, 0u);
    [example performAction:@"allow"]; XCTAssertTrue([example selectTabWithIdentifier:@"page.2"]);
}
- (void)testStyleAndStructureExamplesPreserveTheirPromises {
    XBShowcaseController *example = (id)[XBCatalogController exampleWithIdentifier:@"itemStyle"]; [example loadViewIfNeeded];
    XCTAssertNotNil([example.tabBar itemForIdentifier:@"page.1"].style);
    [example performAction:@"itemStyle"]; XCTAssertNil([example.tabBar itemForIdentifier:@"page.1"].style);
    example = (id)[XBCatalogController exampleWithIdentifier:@"structure"]; [example loadViewIfNeeded]; example.selectedIndex = 1;
    UIViewController *previous = example.selectedViewController;
    [example performAction:@"reorder"]; XCTAssertEqual(example.selectedViewController, previous);
    NSString *selectedIdentifier = example.tabBar.items[example.tabBar.selectedIndex].identifier;
    [example performAction:@"rebuild"]; XCTAssertNotEqual(example.selectedViewController, previous);
    XCTAssertEqualObjects(example.tabBar.items[example.tabBar.selectedIndex].identifier, selectedIdentifier);
    [example performAction:@"actionsOnly"];
    XCTAssertEqual(example.selectedIndex, NSNotFound); XCTAssertEqual(example.tabBar.items.count, 2u);
    XCTAssertTrue([example selectTabWithIdentifier:@"action.first"]); XCTAssertNil(example.selectedViewController);
}
- (void)testStandaloneControlsAndMultipleContainersWork {
    UITableViewController *standalone = (id)[XBCatalogController exampleWithIdentifier:@"standalone"]; [standalone loadViewIfNeeded];
    for (NSUInteger i = 0; i < 4; i++) [standalone.tableView.delegate tableView:standalone.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
    UIViewController *multiple = [XBCatalogController exampleWithIdentifier:@"multiple"]; [multiple loadViewIfNeeded];
    XCTAssertEqual(multiple.childViewControllers.count, 2u);
    XBTabContainerViewController *upper = (id)multiple.childViewControllers[0], *lower = (id)multiple.childViewControllers[1];
    NSUInteger previous = lower.selectedIndex; upper.selectedIndex = 2; XCTAssertEqual(lower.selectedIndex, previous);
}

- (UIWindow *)showController:(UIViewController *)controller {
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState == UISceneActivationStateForegroundActive) { scene = (id)candidate; break; }
    XCTAssertNotNil(scene);
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.rootViewController = controller; [window makeKeyAndVisible]; [window layoutIfNeeded]; return window;
}
- (void)attachWindow:(UIWindow *)window name:(NSString *)name {
    [window layoutIfNeeded];
    UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds] imageWithActions:^(UIGraphicsImageRendererContext *context) { [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES]; }];
    XCTAttachment *attachment = [XCTAttachment attachmentWithImage:image]; attachment.name = name; attachment.lifetime = XCTAttachmentLifetimeKeepAlways; [self addAttachment:attachment];
}
- (void)testCatalogCellsOpenExamplesAndCanReturn {
    XBCatalogController *catalog = [XBCatalogController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:catalog];
    UIWindow *window = [self showController:navigation];
    [self attachWindow:window name:@"Catalog"];
    [catalog tableView:catalog.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:0]];
    NSPredicate *displayed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return catalog.presentedViewController.viewIfLoaded.window != nil && !catalog.presentedViewController.isBeingPresented; }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:displayed object:catalog]] timeout:5];
    XCTAssertTrue([catalog.presentedViewController isKindOfClass:XBShowcaseController.class]);
    [self attachWindow:window name:@"Raised"];
    XCTestExpectation *dismissed = [self expectationWithDescription:@"Back to catalog"];
    [catalog.presentedViewController dismissViewControllerAnimated:NO completion:^{ [dismissed fulfill]; }];
    [self waitForExpectations:@[dismissed] timeout:5];
    XCTAssertNil(catalog.presentedViewController);
    [catalog tableView:catalog.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:2]];
    NSPredicate *pushed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return navigation.topViewController != catalog && navigation.topViewController.viewIfLoaded.window != nil && navigation.transitionCoordinator == nil; }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:pushed object:navigation]] timeout:5];
    XCTAssertEqual(navigation.viewControllers.count, 2u);
    [self attachWindow:window name:@"Standalone"];
    [navigation popViewControllerAnimated:NO]; XCTAssertEqual(navigation.topViewController, catalog);
    window.hidden = YES; window.rootViewController = nil;
}
- (void)testDecodedAndSwiftExamplesActuallyOpen {
    UITableViewController *initialization = (id)[XBCatalogController exampleWithIdentifier:@"initialization"];
    UIWindow *window = [self showController:[[UINavigationController alloc] initWithRootViewController:initialization]];
    for (NSUInteger row = 0; row < 2; row++) {
        [initialization.tableView.delegate tableView:initialization.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        NSPredicate *displayed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return initialization.presentedViewController.viewIfLoaded.window != nil && !initialization.presentedViewController.isBeingPresented; }];
        [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:displayed object:initialization]] timeout:5];
        XBTabContainerViewController *tabs = (id)initialization.presentedViewController;
        XCTAssertTrue([tabs isKindOfClass:XBTabContainerViewController.class]); XCTAssertEqual(tabs.viewControllers.count, 1u);
        [self attachWindow:window name:row == 0 ? @"Decoded" : @"Swift"];
        XCTestExpectation *dismissed = [self expectationWithDescription:@"Back from initialization sample"];
        [tabs dismissViewControllerAnimated:NO completion:^{ [dismissed fulfill]; }]; [self waitForExpectations:@[dismissed] timeout:5];
    }
    window.hidden = YES; window.rootViewController = nil;
}
@end
