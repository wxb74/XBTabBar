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
- (void)testAutomaticPlacementUsesSystemTraitsWithoutReplacingPages {
    XBTabContainerViewController *tabs = [self twoPages];
    XCTAssertEqual(tabs.tabBarPlacement, XBTabBarPlacementAutomatic);
    UIViewController *page = tabs.selectedViewController;
    [tabs loadViewIfNeeded];
    tabs.view.frame = CGRectMake(0, 0, 466, 678);
    [tabs.view layoutIfNeeded];
    XBTabBarPlacement expected = XBTabBarPlacementBottom;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
    if (@available(iOS 27.1, *)) {
        if (tabs.traitCollection.verticalBarEdge == UIVerticalBarEdgeLeading) expected = XBTabBarPlacementFloatingLeft;
        if (tabs.traitCollection.verticalBarEdge == UIVerticalBarEdgeTrailing) expected = XBTabBarPlacementFloatingRight;
    }
#endif
    XCTAssertEqual(tabs.resolvedTabBarPlacement, expected);
    XCTAssertEqual(tabs.selectedViewController, page);
    XCTAssertEqual(tabs.tabBar.isVertical, expected != XBTabBarPlacementBottom);
}

- (void)testFloatingPlacementChangesPreserveBusinessInsets {
    XBTabContainerViewController *tabs = [XBTabContainerViewController new];
    UIViewController *page = [UIViewController new];
    UIEdgeInsets original = UIEdgeInsetsMake(1, 2, 7, 4);
    page.additionalSafeAreaInsets = original;
    tabs.viewControllers = @[page];
    [tabs loadViewIfNeeded]; tabs.view.frame = CGRectMake(0, 0, 320, 500);
    for (NSUInteger i = 0; i < 20; i++) tabs.tabBarPlacement = i % 2 ? XBTabBarPlacementFloatingRight : XBTabBarPlacementFloatingLeft;
    XCTAssertEqual(page.additionalSafeAreaInsets.left, original.left);
    XCTAssertEqual(page.additionalSafeAreaInsets.right, original.right + 80);
    XCTAssertEqual(page.additionalSafeAreaInsets.bottom, original.bottom);
    [tabs setTabBarHidden:YES animated:NO];
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(page.additionalSafeAreaInsets, original));
    [tabs setViewControllers:@[] tabBarItems:@[]];
    XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(page.additionalSafeAreaInsets, original));
}

- (void)testVerticalSelectedImageOnlyFallsBackToTitleWhenUnselected {
    XBTabBarView *bar = [XBTabBarView new];
    XBTabBarItem *item = [[XBTabBarItem alloc] initWithIdentifier:@"image" title:@"课程"
                                                        image:nil selectedImage:[UIImage systemImageNamed:@"play"]];
    [bar setItems:@[[self page:@"home"], item]];
    bar.vertical = YES;
    UIControl *button = [bar valueForKey:@"buttons"][1];
    XCTAssertFalse([[button valueForKey:@"textLabel"] isHidden]);
    XCTAssertEqualObjects(button.accessibilityLabel, @"课程");
    bar.selectedIndex = 1;
    XCTAssertTrue([[button valueForKey:@"textLabel"] isHidden]);
    XCTAssertNotNil([[button valueForKey:@"iconView"] image]);
}

- (void)assertSelectedEntryVisible:(XBTabBarView *)bar {
    [bar layoutIfNeeded];
    UIScrollView *scroll = [bar valueForKey:@"buttonScrollView"];
    UIView *button = [bar valueForKey:@"buttons"][bar.selectedIndex];
    CGRect target = [button convertRect:button.bounds toView:scroll];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, -0.5, -0.5), target),
                  @"viewport=%@ target=%@ content=%@", NSStringFromCGRect(scroll.bounds),
                  NSStringFromCGRect(target), NSStringFromCGSize(scroll.contentSize));
}

- (void)testVerticalReorderAndRowHeightChangeRevealSelectedEntry {
    XBTabBarView *bar = [XBTabBarView new];
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < 7; i++) [items addObject:[self page:[@(i) stringValue]]];
    [bar setItems:items]; bar.vertical = YES; bar.frame = CGRectMake(0, 0, 56, 148);
    [bar layoutIfNeeded];
    XBTabBarItem *selected = items.firstObject;
    [items removeObjectAtIndex:0]; [items addObject:selected];
    [bar setItems:items];
    XCTAssertEqual(bar.selectedIndex, 6u);
    [self assertSelectedEntryVisible:bar];
    XBTabBarAppearance *appearance = bar.appearance;
    appearance.floatingItemHeight = 80;
    bar.appearance = appearance;
    [self assertSelectedEntryVisible:bar];
}

- (void)testFloatingBarRequiresOneWholeConfiguredRowAndStaysWithinWidth {
    XBTabContainerViewController *tabs = [self twoPages];
    [tabs loadViewIfNeeded];
    tabs.view.frame = CGRectMake(0, 0, 320, 80);
    XBTabBarAppearance *appearance = tabs.tabBarAppearance;
    appearance.floatingItemHeight = 80; appearance.floatingTopClearance = 0; appearance.floatingMargin = 0;
    tabs.tabBarAppearance = appearance; tabs.tabBarPlacement = XBTabBarPlacementFloatingRight;
    XCTAssertTrue(tabs.tabBar.hidden);
    XCTAssertEqual(tabs.tabBarContentInsets.right, 0);
    tabs.view.frame = CGRectMake(0, 0, 320, 400);
    appearance.floatingWidth = 500;
    tabs.tabBarAppearance = appearance;
    XCTAssertTrue(CGRectGetMinX(tabs.tabBar.frame) >= 0);
    XCTAssertTrue(CGRectGetMaxX(tabs.tabBar.frame) <= 320);
}

- (void)testReappearingContainerDiscardsMissedKeyboardFrame {
    XBTabContainerViewController *tabs = [self twoPages];
    [tabs loadViewIfNeeded];
    [tabs setValue:[NSValue valueWithCGRect:CGRectMake(0, 300, 320, 300)] forKey:@"keyboardFrameInScreen"];
    [tabs viewWillAppear:NO];
    XCTAssertTrue(CGRectIsNull([[tabs valueForKey:@"keyboardFrameInScreen"] CGRectValue]));
    [tabs viewDidAppear:NO];
}

- (void)testVerticalLayoutPreservesButtonIdentityAndEntryState {
    XBTabBarView *bar = [XBTabBarView new];
    [bar setItems:@[[self page:@"a"], [self page:@"b"]]];
    [bar setBadgeValue:@"12" forIdentifier:@"b"];
    bar.selectedIndex = 1;
    NSArray *buttons = [[bar valueForKey:@"buttons"] copy];
    bar.vertical = YES;
    bar.frame = CGRectMake(0, 0, 56, 104);
    [bar layoutIfNeeded];
    XCTAssertEqualObjects(buttons, [bar valueForKey:@"buttons"]);
    XCTAssertEqual(bar.selectedIndex, 1u);
    XCTAssertEqualObjects([bar itemForIdentifier:@"b"].badgeValue, @"12");
    UIControl *button = buttons.firstObject;
    XCTAssertTrue(button.bounds.size.height >= 44);
    XCTAssertTrue(button.bounds.size.width >= 44);
    XCTAssertTrue([[button valueForKey:@"textLabel"] isHidden]);
    XCTAssertEqualObjects(button.accessibilityLabel, @"a");
    bar.vertical = NO;
    [bar layoutIfNeeded];
    XCTAssertFalse([[button valueForKey:@"textLabel"] isHidden]);
    XCTAssertEqualObjects(buttons, [bar valueForKey:@"buttons"]);
}

- (void)testVerticalOverflowKeepsEveryEntryReachable {
    XBTabBarView *bar = [XBTabBarView new];
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger index = 0; index < 7; index++) [items addObject:[self page:[@(index) stringValue]]];
    [bar setItems:items]; bar.vertical = YES;
    bar.frame = CGRectMake(0, 0, 56, 148);
    bar.selectedIndex = 6;
    [bar layoutIfNeeded];
    UIScrollView *scroll = [bar valueForKey:@"buttonScrollView"];
    XCTAssertEqual(bar.items.count, 7u);
    XCTAssertTrue(scroll.scrollEnabled);
    XCTAssertTrue(scroll.contentSize.height > scroll.bounds.size.height);
    XCTAssertTrue(scroll.contentOffset.y > 0);
    XCTAssertNil([bar hitTest:CGPointMake(28, 170) withEvent:nil]);
}

- (void)testFloatingAppearanceHasValueSemantics {
    XBTabBarAppearance *original = [XBTabBarAppearance new];
    original.floatingWidth = 64; original.floatingItemHeight = 48;
    original.floatingMargin = 16; original.floatingTopClearance = 120;
    XBTabBarAppearance *copy = [original copy];
    original.floatingWidth = 90;
    XCTAssertEqual(copy.floatingWidth, 64);
    XCTAssertEqual(copy.floatingItemHeight, 48);
    XCTAssertEqual(copy.floatingMargin, 16);
    XCTAssertEqual(copy.floatingTopClearance, 120);
}

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
    XBTabContainerViewController *tabs = [self twoPages];
    tabs.tabBarPlacement = XBTabBarPlacementBottom;
    [tabs loadViewIfNeeded];
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
    tabs.tabBarPlacement = XBTabBarPlacementBottom;
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
    tabs.tabBarPlacement = XBTabBarPlacementBottom;
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
    tabs.tabBarPlacement = XBTabBarPlacementBottom;
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
