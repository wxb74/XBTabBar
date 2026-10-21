#import <XCTest/XCTest.h>
#import "XBTabContainerViewController.h"

@interface XBPageProbe : UIViewController
@property NSUInteger appearances;
@property NSUInteger disappearances;
@end
@implementation XBPageProbe
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; self.appearances++; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; self.disappearances++; }
@end

@interface XBSelectionProbe : NSObject <XBTabContainerDelegate, UINavigationControllerDelegate>
@property BOOL rejects;
@property NSUInteger selections;
@property NSUInteger actions;
@property BOOL reselected;
@property (copy) void (^onAdmission)(XBTabContainerViewController *);
@end
@implementation XBSelectionProbe
- (BOOL)tabContainer:(XBTabContainerViewController *)container shouldSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index {
    if (self.onAdmission) self.onAdmission(container);
    return !self.rejects;
}
- (void)tabContainer:(XBTabContainerViewController *)container didSelectItem:(XBTabBarItem *)item atIndex:(NSUInteger)index reselected:(BOOL)reselected {
    self.selections++; self.reselected = reselected;
}
- (void)tabContainer:(XBTabContainerViewController *)container didTriggerActionItem:(XBTabBarItem *)item atIndex:(NSUInteger)index { self.actions++; }
@end

@interface XBTabBarTests : XCTestCase
@end
@implementation XBTabBarTests
- (XBTabBarItem *)page:(NSString *)identifier {
    return [[XBTabBarItem alloc] initWithIdentifier:identifier title:identifier image:[UIImage systemImageNamed:@"house"] selectedImage:nil];
}
- (XBTabContainerViewController *)twoPages {
    XBTabContainerViewController *tabs = [XBTabContainerViewController new];
    [tabs setViewControllers:@[[XBPageProbe new], [XBPageProbe new]] tabBarItems:@[[self page:@"a"], [self page:@"b"]]];
    return tabs;
}
- (void)testDefaultIdentifiersSurviveReorderingAndRemoval {
    XBTabContainerViewController *tabs = [XBTabContainerViewController new];
    UINavigationController *a = [UINavigationController new], *b = [UINavigationController new];
    tabs.viewControllers = @[a, b]; tabs.selectedIndex = 1;
    NSString *identifier = tabs.tabBar.items[1].identifier;
    tabs.viewControllers = @[b, a];
    XCTAssertEqual(tabs.selectedViewController, b);
    XCTAssertEqual(tabs.selectedIndex, 0u);
    XCTAssertEqualObjects(tabs.tabBar.items[0].identifier, identifier);
    tabs.viewControllers = @[a]; tabs.viewControllers = @[b, a];
    XCTAssertEqualObjects(tabs.tabBar.items[0].identifier, identifier);
}
- (void)testExplicitIdentifiersRestoreAcrossNewControllerObjects {
    XBTabContainerViewController *tabs = [self twoPages]; tabs.selectedIndex = 1;
    UIViewController *replacement = [UIViewController new];
    [tabs setViewControllers:@[replacement, [UIViewController new]] tabBarItems:@[[self page:@"b"], [self page:@"a"]]];
    XCTAssertEqual(tabs.selectedViewController, replacement);
}
- (void)testInputAndOutputItemsAndNestedStylesAreIsolated {
    XBTabBarView *bar = [XBTabBarView new];
    XBTabBarItem *item = [self page:@"a"];
    XBTabBarItemStyle *style = [XBTabBarItemStyle new]; style.imageSize = CGSizeMake(20, 20); item.style = style;
    [bar setItems:@[item]];
    item.title = @"input changed"; item.style.imageSize = CGSizeZero;
    XBTabBarItem *snapshot = bar.items.firstObject;
    snapshot.title = @"output changed"; snapshot.enabled = NO; snapshot.style.imageSize = CGSizeZero;
    XCTAssertEqualObjects([bar itemForIdentifier:@"a"].title, @"a");
    XCTAssertTrue([bar itemForIdentifier:@"a"].isEnabled);
    XCTAssertTrue(CGSizeEqualToSize([bar itemForIdentifier:@"a"].style.imageSize, CGSizeMake(20, 20)));
    [bar updateItem:snapshot];
    XCTAssertEqualObjects([bar itemForIdentifier:@"a"].title, @"output changed");
    XCTAssertFalse([bar itemForIdentifier:@"a"].isEnabled);
}
- (void)testAppearanceReadsAndWritesAreIsolatedAndApplyInsets {
    XBTabContainerViewController *tabs = [self twoPages]; [tabs loadViewIfNeeded];
    XBTabBarAppearance *style = tabs.tabBarAppearance; style.contentHeight = 70;
    XCTAssertEqual(tabs.tabBarAppearance.contentHeight, 49);
    XCTAssertEqual(tabs.tabBar.appearance.contentHeight, 49);
    tabs.tabBarAppearance = style; style.contentHeight = 90;
    XCTAssertEqual(tabs.tabBarAppearance.contentHeight, 70);
    XCTAssertEqual(tabs.tabBar.appearance.contentHeight, 70);
    XCTAssertEqual(tabs.selectedViewController.additionalSafeAreaInsets.bottom, 70);
    XBTabBarAppearance *barStyle = tabs.tabBar.appearance; barStyle.contentHeight = 12;
    XCTAssertEqual(tabs.tabBar.appearance.contentHeight, 70);
}
- (id)decodeBaseObject:(id)object asClass:(Class)target {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:&error];
    XCTAssertNil(error);
    NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    decoder.requiresSecureCoding = NO;
    [decoder setClass:target forClassName:NSStringFromClass([object class])];
    id result = [decoder decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [decoder finishDecoding];
    XCTAssertNil(error);
    return result;
}
- (void)testDecodedBarHasWorkingButtonsAndDefaults {
    XBTabBarView *bar = [self decodeBaseObject:[UIView new] asClass:XBTabBarView.class];
    XCTAssertEqual(bar.appearance.contentHeight, 49);
    [bar setItems:@[[self page:@"a"]]];
    __block NSUInteger calls = 0;
    bar.selectionAnimation = ^(UIView *view, BOOL reselected) { calls++; };
    [bar animateSelectionAtIndex:0 reselected:NO];
    if (!UIAccessibilityIsReduceMotionEnabled() && UIView.areAnimationsEnabled) XCTAssertEqual(calls, 1u);
    XCTAssertEqual(bar.selectedIndex, 0u);
}
- (void)testDecodedContainerHasWorkingSelectionAndInsets {
    XBTabContainerViewController *tabs = [self decodeBaseObject:[UIViewController new] asClass:XBTabContainerViewController.class];
    XCTAssertEqual(tabs.selectedIndex, NSNotFound);
    tabs.viewControllers = @[[UIViewController new], [UIViewController new]];
    tabs.selectedIndex = 1; [tabs loadViewIfNeeded];
    XCTAssertEqual(tabs.tabBar.items.count, 2u);
    XCTAssertEqual(tabs.selectedViewController.additionalSafeAreaInsets.bottom, 49);
}
- (void)testRejectedDisabledAndSilentSelection {
    XBTabContainerViewController *tabs = [self twoPages];
    XBSelectionProbe *probe = [XBSelectionProbe new]; tabs.selectionDelegate = probe; probe.rejects = YES;
    XCTAssertFalse([tabs selectTabWithIdentifier:@"b"]);
    XCTAssertEqual(tabs.selectedIndex, 0u);
    XCTAssertEqual(tabs.tabBar.selectedIndex, 0u);
    tabs.selectedIndex = 1; XCTAssertEqual(probe.selections, 0u);
    XBTabBarItem *item = [tabs.tabBar itemForIdentifier:@"a"]; item.enabled = NO; [tabs.tabBar updateItem:item];
    probe.rejects = NO; XCTAssertFalse([tabs selectTabWithIdentifier:@"a"]);
}
- (void)testActionDoesNotChangePageOrSelectionCallback {
    XBTabContainerViewController *tabs = [self twoPages];
    XBTabBarItem *action = [[XBTabBarItem alloc] initWithIdentifier:@"action" title:@"Action" image:nil selectedImage:nil kind:XBTabBarItemKindAction];
    [tabs setViewControllers:tabs.viewControllers tabBarItems:@[[self page:@"a"], action, [self page:@"b"]]];
    XCTAssertFalse([tabs selectTabWithIdentifier:@"action"]);
    XBSelectionProbe *probe = [XBSelectionProbe new]; tabs.selectionDelegate = probe;
    XCTAssertTrue([tabs selectTabWithIdentifier:@"action"]);
    XCTAssertEqual(probe.actions, 1u); XCTAssertEqual(probe.selections, 0u); XCTAssertEqual(tabs.selectedIndex, 0u);
    XCTAssertTrue([tabs selectTabWithIdentifier:@"b"]);
    XCTAssertEqual(tabs.selectedIndex, 1u); XCTAssertEqual(tabs.tabBar.selectedIndex, 2u);
}
- (void)testAdmissionRebuildCannotSelectStalePosition {
    XBTabContainerViewController *tabs = [self twoPages];
    XBSelectionProbe *probe = [XBSelectionProbe new]; tabs.selectionDelegate = probe;
    probe.onAdmission = ^(XBTabContainerViewController *container) {
        [container setViewControllers:@[[UIViewController new]] tabBarItems:@[[self page:@"c"]]];
    };
    XCTAssertFalse([tabs selectTabWithIdentifier:@"b"]);
    XCTAssertEqualObjects(tabs.tabBar.items.firstObject.identifier, @"c");
    XCTAssertEqual(probe.selections, 0u);
}
- (void)testSelectionLifecycleAndReselectionArePaired {
    XBTabContainerViewController *tabs = [self twoPages]; [tabs loadViewIfNeeded];
    XBPageProbe *a = (id)tabs.viewControllers[0], *b = (id)tabs.viewControllers[1];
    [tabs beginAppearanceTransition:YES animated:NO]; [tabs endAppearanceTransition];
    XBSelectionProbe *probe = [XBSelectionProbe new]; tabs.selectionDelegate = probe;
    [tabs selectTabWithIdentifier:@"b"]; [tabs selectTabWithIdentifier:@"b"];
    XCTAssertEqual(a.appearances, 1u); XCTAssertEqual(a.disappearances, 1u);
    XCTAssertEqual(b.appearances, 1u); XCTAssertEqual(b.disappearances, 0u); XCTAssertTrue(probe.reselected);
    [tabs beginAppearanceTransition:NO animated:NO]; [tabs endAppearanceTransition];
    XCTAssertEqual(b.disappearances, 1u);
}
- (void)testRemovingNavigationRestoresDelegateAndOriginalInsets {
    XBTabContainerViewController *tabs = [XBTabContainerViewController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    XBSelectionProbe *original = [XBSelectionProbe new]; navigation.delegate = original;
    navigation.additionalSafeAreaInsets = UIEdgeInsetsMake(1, 2, 7, 4);
    tabs.viewControllers = @[navigation]; [tabs loadViewIfNeeded];
    XCTAssertNotEqual(navigation.delegate, original);
    XCTAssertEqual(navigation.additionalSafeAreaInsets.bottom, 56);
    [tabs setViewControllers:@[] tabBarItems:@[]];
    XCTAssertEqual(navigation.delegate, original);
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(navigation.additionalSafeAreaInsets, UIEdgeInsetsMake(1, 2, 7, 4)));
    XCTAssertNil(navigation.parentViewController); XCTAssertNil(tabs.selectedViewController); XCTAssertEqual(tabs.selectedIndex, NSNotFound);
}
- (void)testStandaloneBarRestoresPageIdentifierAcrossActionReordering {
    XBTabBarView *bar = [XBTabBarView new];
    XBTabBarItem *a = [self page:@"a"], *b = [self page:@"b"];
    XBTabBarItem *action = [[XBTabBarItem alloc] initWithIdentifier:@"action" title:@"Action" image:nil selectedImage:nil kind:XBTabBarItemKindAction];
    [bar setItems:@[a, action, b]]; bar.selectedIndex = 2;
    [bar setItems:@[b, a, action]];
    XCTAssertEqual(bar.selectedIndex, 0u);
    bar.selectedIndex = 2;
    XCTAssertEqual(bar.selectedIndex, 0u);
    [bar setItems:@[]];
    XCTAssertEqual(bar.selectedIndex, NSNotFound); XCTAssertEqual(bar.items.count, 0u);
}
- (void)testNavigationPushAndPopRestoreBarAndInsets {
    XBTabContainerViewController *tabs = [XBTabContainerViewController new];
    UIViewController *root = [UIViewController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    tabs.viewControllers = @[navigation]; [tabs loadViewIfNeeded];
    UIViewController *detail = [UIViewController new]; detail.hidesBottomBarWhenPushed = YES;
    [navigation pushViewController:detail animated:NO];
    [tabs navigationController:navigation didShowViewController:detail animated:NO];
    XCTAssertTrue(tabs.isTabBarHidden); XCTAssertEqual(navigation.additionalSafeAreaInsets.bottom, 0);
    [navigation popViewControllerAnimated:NO];
    [tabs navigationController:navigation didShowViewController:root animated:NO];
    XCTAssertFalse(tabs.isTabBarHidden); XCTAssertEqual(navigation.additionalSafeAreaInsets.bottom, 49);
}
@end
