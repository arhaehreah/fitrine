// The now playing bar's rows of the redesign, the Mini player section of the Player page
// (Redesigned/Player/PlayerSettings.m puts them there).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Redesigned/Navbar/Navbar.h"
#import "NowPlayingBar.h"

NSArray<SGModRow *> *SGRNowPlayingBarRows(void) {
    // The tab bar reads the switch as each scroll goes; a bar minimized when it goes off grows back at once.
    SGModRow *minimize = SGSwitchRow(@"Apple Music style", @"Between two tabs as a page scrolls down", SGRKeyNavbarMinimize);
    minimize.changed = ^(BOOL on) {
        if (!on) SGRSetTabBarMinimized(NO, NO);
        SGRRefreshTabBar();
    };
    // The capsule bar (iOS < 26) only: the glass bar always comes back as the page is scrolled up.
    SGModRow *expandOnUp = SGRLegacyTabBarOn() ? SGOptionRow(@"Expand on scroll up", @"Off: only at the top of the page or on a tap on a tab", SGRKeyNavbarExpandOnScrollUp) : nil;
    expandOnUp.waitsOn = SGRKeyNavbarMinimize;
    SGModRow *inlineConnect = SGOptionRow(@"Device button", @"Kept on the bar between the tabs", SGRKeyBarInlineConnect);
    inlineConnect.waitsOn = SGRKeyNavbarMinimize;
    SGModRow *inlineArtist = SGOptionRow(@"Artist under the title when minimized", @"A second line on the bar between the tabs, when it fits", SGRKeyBarInlineArtist);
    inlineArtist.waitsOn = SGRKeyNavbarMinimize;
    inlineArtist.changed = ^(BOOL on) { SGRNowPlayingBarFollowTabBar(); };
    SGModRow *next = SGOptionRow(@"Next button", @"After play on the full now playing bar", SGRKeyBarNextButton);
    next.changed = ^(BOOL on) { SGRNowPlayingBarFollowTabBar(); };
    SGModRow *shape = SGChoiceRow(@"Artwork shape", nil, SGRKeyBarArtworkShape,
                                  @[@"Rounded square", @"Circle"],
                                  SGRBarArtworkShapeCircle);
    shape.chosen = ^(NSInteger index) { SGRNowPlayingBarFollowTabBar(); };
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObject:minimize];
    if (expandOnUp) [rows addObject:expandOnUp];
    [rows addObjectsFromArray:@[
        inlineConnect,
        inlineArtist,
        next,
        shape,
        SGHideRow(@"Hide the device button", @"On the full now playing bar", SGRHideBarConnect),
        // Spotify's own flag for the bar's save button, forced off: Spotify leaves the button out.
        SGKillRow(@"Hide the like button", @"ios-feature-nowplayingbar.add_button"),
    ]];
    return rows;
}
