// Mod Settings' main page as App/ModSettings.x builds it, opened the way holding Home opens it
// (SGOpenModSettings), with the real App/Pages.m behind its Redesigned UI switch and the real Settings/
// framework; stubs.m stands in for every page a row opens. The launch line sets the look up and then plays
// actions, one every 0.9 s from 1 s in; screenshot after.
//
//     THEOS=$HOME/theos ./build.sh && xcrun simctl install <udid> build/ModSettingsHarness.app
//     xcrun simctl launch <udid> com.vitrine.modsettingsharness [setup...] [action...]
//
// Setup: redesign (Redesigned UI stored on), warning (a red environment row at the top), keep (the stored
// look stays; otherwise it is cleared first).
// Actions: toggle=<section>.<row> (that row's switch flipped the way a tap does), cancel (the alert that
// switch brings up closed with Later), bottom (scrolled to the end), dump (the rows of each section and
// what each reads beside its chevron, to the log), gated (a page of a switch, ten rows, a headed and noted
// section of twelve rows shown only while the switch is on, and a row that comes by itself), later (that row
// let come; the page's ticker brings it), top (scrolled to the start), layout (the scroll offset, and each
// section's rows and heading and note heights, to the log), needs (the Lock screen artwork section below iOS
// 26), tap=<section>.<row> (that row selected, and the alert it brings up logged), rows (the row the mod adds to
// Spotify's settings list and drawer, after each list is emptied of its subviews, counted to the log).
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Settings/SGModPage.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/Flags/Flags.h"
#import "App/About/About.h"
#import "../harness-fail.h"

// Spotify's page protocol, so SGRegisterPages finds one and the page is pushed as on the phone.
@protocol SPTPageController <NSObject>
@end

BOOL SGHarnessWarning;

@interface SGSearchDestinationCheck : NSObject <UISearchControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UINavigationController *nav;
@property (nonatomic, strong) SGModPage *root;
@property (nonatomic) NSUInteger destination;
@property (nonatomic, weak) id<UISearchControllerDelegate> resultsDelegate;
@end

@implementation SGSearchDestinationCheck
- (void)start {
    self.root = (SGModPage *)self.nav.topViewController;
    self.nav.delegate = self;
    SGSearchForgetRecents();
    [self search];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        HARNESS_FAIL(@"search did not finish opening destination %lu", (unsigned long)self.destination);
    });
}
- (void)search {
    UISearchController *search = SGSettingsSearchField(self.root);
    if (search.delegate != self) self.resultsDelegate = search.delegate;
    search.delegate = self;
    search.searchBar.text = self.destination == 0
        ? @"Audio effects"
        : @"All flags";
    search.active = YES;
}
- (void)didPresentSearchController:(UISearchController *)search {
    [search.searchResultsUpdater updateSearchResultsForSearchController:search];
    UITableView *table = ((UITableViewController *)search.searchResultsController).tableView;
    HARNESS_CHECK([table.dataSource tableView:table numberOfRowsInSection:1] > 0);
    [table.delegate tableView:table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
}
- (void)didDismissSearchController:(UISearchController *)search {
    if ([self.resultsDelegate respondsToSelector:_cmd]) [self.resultsDelegate didDismissSearchController:search];
}
- (void)navigationController:(UINavigationController *)nav didShowViewController:(UIViewController *)page animated:(BOOL)animated {
    if (page == self.root) {
        [self search];
        return;
    }
    NSString *expected = self.destination == 0 ? @"Audio effects" : @"All flags";
    if (![page.title isEqualToString:expected]) HARNESS_FAIL(@"expected %@, opened %@", expected, page.title);
    HARNESS_CHECK(![page isKindOfClass:SGModPage.class]);
    HARNESS_CHECK(!SGSettingsSearchField(self.root).active);
    if (++self.destination == 2) {
        SGSearchForgetRecents();
        NSLog(@"[harness] search destinations PASS");
        exit(0);
    }
    [nav popToViewController:self.root animated:YES];
}
@end

static void refactorChecks(void) {
    // The Mod page keeps its action's symbol when row decoration is shared with Settings.
    SGModPage *about = (SGModPage *)SGAboutPage();
    SGModRow *reset = nil;
    for (SGModSection *section in about.sections) {
        for (SGModRow *row in section.rows) {
            if ([row.title isEqualToString:@"Reset all settings"]) reset = row;
        }
    }
    HARNESS_CHECK([reset.symbol isEqualToString:@"trash"]);

    extern NSURL *SGHarnessStorageURI;
    NSUInteger storage = [about.sections indexOfObjectPassingTest:^BOOL(SGModSection *section, NSUInteger idx, BOOL *stop) {
        return [section.rows.firstObject.key isEqualToString:SGKeyShowCacheLimit];
    }];
    HARNESS_CHECK(storage != NSNotFound);
    SGModSection *group = about.sections[storage];
    HARNESS_CHECK(group.rows.count == 2 && group.rows.firstObject.defaultOn && group.footer.length);
    UITableView *table = about.tableView;
    table.frame = CGRectMake(0, 0, 375, 667);
    NSIndexPath *firstRow = [NSIndexPath indexPathForRow:0 inSection:storage];
    NSIndexPath *action = [NSIndexPath indexPathForRow:1 inSection:storage];
    [table reloadData];
    [table scrollToRowAtIndexPath:firstRow atScrollPosition:UITableViewScrollPositionTop animated:NO];
    [table layoutIfNeeded];
    UITableViewCell *toggleCell = [table cellForRowAtIndexPath:firstRow], *actionCell = [table cellForRowAtIndexPath:action];
    HARNESS_CHECK(toggleCell && actionCell && CGRectGetMaxY(toggleCell.frame) <= CGRectGetMinY(actionCell.frame));
    HARNESS_CHECK(CGRectGetMaxY(actionCell.frame) <= CGRectGetMinY([table rectForFooterInSection:storage]));
    [table.delegate tableView:table didSelectRowAtIndexPath:action];
    HARNESS_CHECK([SGHarnessStorageURI.absoluteString isEqualToString:@"spotify:config:storage"]);

    // A navigation controller reached through the source's parents includes itself in the search.
    UIViewController *home = [UIViewController new];
    UINavigationController *root = [[UINavigationController alloc] initWithRootViewController:home];
    SGOpenModSettings(home.view);
    HARNESS_CHECK([root.topViewController.title isEqualToString:@"Retrine"]);

    // A deeper stack in the first child's subtree wins over a shallower later sibling.
    UIViewController *container = [UIViewController new], *wrapper = [UIViewController new];
    UINavigationController *first = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    UINavigationController *later = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    [container addChildViewController:wrapper];
    [wrapper didMoveToParentViewController:container];
    [wrapper addChildViewController:first];
    [first didMoveToParentViewController:wrapper];
    [container addChildViewController:later];
    [later didMoveToParentViewController:container];
    SGOpenModSettings(container.view);
    HARNESS_CHECK([first.topViewController.title isEqualToString:@"Retrine"]);
    NSLog(@"[harness] refactor checks PASS");
}
static void findViews(UIView *root, Class kind, NSMutableArray *found) {
    if ([root isKindOfClass:kind]) [found addObject:root];
    for (UIView *sub in root.subviews) findViews(sub, kind, found);
}

// With `rows` on the launch line, Spotify's settings list controller and the side drawer's list by their own
// names, made before ModSettings.x's %ctor hooks them (constructor priorities hold within this binary).
static const char *const kDrawerClass = "_TtC23SideDrawer_ListPageImplP33_1D8CA7A9CC41E8D184AF8B9AAE4E684E28SideDrawerListCollectionView";
static const char *const kSettingsClass = "_TtC21Settings_PlatformImpl26SettingsListViewController";

__attribute__((constructor(101))) static void harnessClasses(void) {
    if (![NSProcessInfo.processInfo.arguments containsObject:@"rows"]) return;
    objc_registerClassPair(objc_allocateClassPair(UICollectionView.class, kDrawerClass, 0));
    objc_registerClassPair(objc_allocateClassPair(UIViewController.class, kSettingsClass, 0));
}

// The `gated` page: a switch, ten rows of filler, then a headed and noted section whose twelve rows show only
// while the switch is on, and a row that comes by itself once `later` is played.
static BOOL sg_later;
static NSString *const kGate = @"spotifyglass.harness.gate";

static UIViewController *gatedPage(void) {
    SGSetEnabled(kGate, NO);
    NSMutableArray<SGModRow *> *filler = [NSMutableArray array], *gated = [NSMutableArray array];
    for (int i = 0; i < 10; i++) [filler addObject:SGStatRow([NSString stringWithFormat:@"Filler %d", i + 1], ^NSString *{ return @"-"; })];
    for (int i = 0; i < 12; i++) {
        SGModRow *row = SGStatRow([NSString stringWithFormat:@"Gated %d", i + 1], ^NSString *{ return @"on"; });
        row.visible = ^BOOL { return SGFlag(kGate, NO); };
        [gated addObject:row];
    }
    SGModRow *later = SGStatRow(@"Came by itself", ^NSString *{ return @"later"; });
    later.visible = ^BOOL { return sg_later; };
    return [[SGModPage alloc] initWithTitle:@"Gated" intro:nil sections:@[
        SGSection(@"Gate", [@[SGOptionRow(@"Show the gated rows", nil, kGate)] arrayByAddingObjectsFromArray:filler]),
        SGNotedSection(@"Gated", gated, @"A note under the gated rows, which goes with them."),
        SGSection(@"Later", @[later]),
    ] footer:nil];
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *nav;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSLog(@"[harness] page protocol %@", NSStringFromProtocol(@protocol(SPTPageController)));
    NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
    if (![args containsObject:@"keep"]) {
        SGSetEnabled(SGKeyRedesign, NO);
        SGSetEnabled(SGKeyRedesignUntested, NO);
    }
    NSMutableArray<NSString *> *actions = [NSMutableArray array];
    for (NSString *arg in [args subarrayWithRange:NSMakeRange(1, args.count - 1)]) {
        if ([arg isEqualToString:@"redesign"]) SGSetEnabled(SGKeyRedesign, YES);
        else if ([arg isEqualToString:@"warning"]) SGHarnessWarning = YES;
        else if (![arg isEqualToString:@"keep"]) [actions addObject:arg];
    }

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    UIViewController *home = [UIViewController new];
    home.view.backgroundColor = UIColor.blackColor;
    self.nav = [[UINavigationController alloc] initWithRootViewController:home];
    self.window.rootViewController = self.nav;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{ SGOpenModSettings(home.view); });

    [actions enumerateObjectsUsingBlock:^(NSString *action, NSUInteger i, BOOL *stop) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1 + 0.9 * i) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[harness] %@", action);
            [self run:action];
        });
    }];
    return YES;
}

- (UITableView *)table {
    return ((UITableViewController *)self.nav.topViewController).tableView;
}

- (NSIndexPath *)pathFrom:(NSString *)text {
    NSArray<NSString *> *at = [text componentsSeparatedByString:@"."];
    return [NSIndexPath indexPathForRow:at[1].integerValue inSection:at[0].integerValue];
}

- (void)run:(NSString *)action {
    NSArray<NSString *> *parts = [action componentsSeparatedByString:@"="];
    NSString *verb = parts.firstObject, *value = parts.count > 1 ? parts[1] : @"";
    UITableView *table = self.table;
    if ([verb isEqualToString:@"toggle"]) {
        NSMutableArray<UIControl *> *controls = [NSMutableArray array];
        findViews([table cellForRowAtIndexPath:[self pathFrom:value]].accessoryView, UIControl.class, controls);
        UIControl *toggle = nil;
        for (UIControl *control in controls) if ([control respondsToSelector:@selector(setOn:animated:)]) toggle = control;
        if (!toggle) { NSLog(@"[harness] no switch at %@", value); return; }
        [(id)toggle setOn:![(id)toggle isOn] animated:YES];
        [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    } else if ([verb isEqualToString:@"cancel"]) {
        UIAlertController *alert = (UIAlertController *)self.nav.presentedViewController;
        if (![alert isKindOfClass:UIAlertController.class]) return;
        NSLog(@"[harness] alert \"%@\": %@", alert.title, alert.message);
        [alert dismissViewControllerAnimated:YES completion:nil];
    } else if ([verb isEqualToString:@"bottom"]) {
        [table setContentOffset:CGPointMake(0, MAX(-table.adjustedContentInset.top, table.contentSize.height - table.bounds.size.height + table.adjustedContentInset.bottom)) animated:NO];
    } else if ([verb isEqualToString:@"gated"]) {
        [self.nav pushViewController:gatedPage() animated:NO];
    } else if ([verb isEqualToString:@"rows"]) {
        // The row ModSettings.x adds to Spotify's settings list and to the side drawer's list, each emptied of its
        // subviews afterward as Spotify can do, then laid out again.
        NSUInteger (^count)(UIView *) = ^NSUInteger(UIView *list) {
            NSUInteger n = 0;
            for (UIView *sub in list.subviews) n += [NSStringFromClass(sub.class) isEqualToString:@"SGModSettingsRow"];
            return n;
        };
        void (^empty)(UIView *) = ^(UIView *list) {
            for (UIView *sub in [list.subviews copy]) [sub removeFromSuperview];
            [list setNeedsLayout];
            [list layoutIfNeeded];
        };
        UICollectionView *drawer = [[NSClassFromString(@(kDrawerClass)) alloc] initWithFrame:CGRectMake(0, 0, 390, 600)
                                                                         collectionViewLayout:[UICollectionViewFlowLayout new]];
        [self.window addSubview:drawer];
        [drawer layoutIfNeeded];
        NSUInteger drawerFirst = count(drawer);
        empty(drawer);
        UIViewController *settings = [NSClassFromString(@(kSettingsClass)) new];
        UICollectionView *list = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 390, 600) collectionViewLayout:[UICollectionViewFlowLayout new]];
        [settings.view addSubview:list];
        [settings viewDidLayoutSubviews];
        [list layoutIfNeeded];
        NSUInteger settingsFirst = count(list);
        empty(list);
        NSLog(@"[harness] rows: drawer %lu on its first layout, %lu after it was emptied; settings %lu, %lu after it was emptied",
              (unsigned long)drawerFirst, (unsigned long)count(drawer), (unsigned long)settingsFirst, (unsigned long)count(list));
        [drawer removeFromSuperview];
    } else if ([verb isEqualToString:@"needs"]) {
        [self.nav pushViewController:[[SGModPage alloc] initWithTitle:@"Lock screen" intro:nil sections:@[
            SGSection(@"Lock screen artwork", @[SGLockScreenArtworkNeedsRow()]),
        ] footer:nil] animated:NO];
    } else if ([verb isEqualToString:@"tap"]) {
        NSIndexPath *path = [self pathFrom:value];
        [table.delegate tableView:table didSelectRowAtIndexPath:path];
        UIAlertController *alert = (UIAlertController *)self.nav.presentedViewController;
        if ([alert isKindOfClass:UIAlertController.class]) NSLog(@"[harness] alert \"%@\": %@", alert.title, alert.message);
    } else if ([verb isEqualToString:@"top"]) {
        [table setContentOffset:CGPointMake(0, -table.adjustedContentInset.top) animated:NO];
    } else if ([verb isEqualToString:@"later"]) {
        sg_later = YES;
    } else if ([verb isEqualToString:@"layout"]) {
        UIEdgeInsets inset = table.adjustedContentInset;
        NSLog(@"[harness] offset %.0f of room %.0f", table.contentOffset.y + inset.top, table.bounds.size.height - inset.top - inset.bottom);
        for (NSInteger section = 0; section < table.numberOfSections; section++) {
            NSLog(@"[harness] section %ld: %ld rows, heading %.0f pt, note %.0f pt", (long)section, (long)[table numberOfRowsInSection:section],
                  [table rectForHeaderInSection:section].size.height, [table rectForFooterInSection:section].size.height);
        }
    } else if ([verb isEqualToString:@"dump"]) {
        NSLog(@"[harness] Redesigned UI stored %d", SGRedesignedUIStored());
        for (NSInteger section = 0; section < table.numberOfSections; section++) {
            NSMutableArray<NSString *> *rows = [NSMutableArray array];
            for (NSInteger row = 0; row < [table numberOfRowsInSection:section]; row++) {
                NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [table.dataSource tableView:table cellForRowAtIndexPath:path];
                NSMutableArray<UILabel *> *labels = [NSMutableArray array];
                findViews(cell.accessoryView, UILabel.class, labels);
                NSString *text = [(UIListContentConfiguration *)cell.contentConfiguration text];
                [rows addObject:labels.count ? [NSString stringWithFormat:@"%@ [%@]", text, labels.firstObject.text] : text];
            }
            NSLog(@"[harness] section %ld: %@", (long)section, [rows componentsJoinedByString:@", "]);
        }
    }
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
    }
}
