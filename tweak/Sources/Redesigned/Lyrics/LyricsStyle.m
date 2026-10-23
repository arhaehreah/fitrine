// Drawing choices, separate from the existing size/spacing/blur/glow/wave look.
#import "LyricsLook.h"

NSNotificationName const SGRLyricsStyleDidChangeNotification = @"spotifyglass.redesign.lyricsStyleDidChange";

NSArray<NSString *> *SGRLyricsStyleIDs(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ identifiers = @[@"apple_music", @"aurora", @"neon", @"shimmer", @"outline"]; });
    return identifiers;
}

SGRLyricsDrawingStyle SGRLyricsDrawingStyleForID(NSString *identifier) {
    NSUInteger index = identifier ? [SGRLyricsStyleIDs() indexOfObject:identifier] : NSNotFound;
    return index == NSNotFound ? SGRLyricsDrawingAppleMusic : (SGRLyricsDrawingStyle)index;
}

NSString *SGRLyricsStyleNow(void) {
    id saved = [NSUserDefaults.standardUserDefaults objectForKey:SGRKeyLyricsStyle];
    return SGRLyricsStyleIDs()[SGRLyricsDrawingStyleForID([saved isKindOfClass:NSString.class] ? saved : nil)];
}

NSString *SGRLyricsStyleName(NSString *identifier) {
    switch (SGRLyricsDrawingStyleForID(identifier)) {
        case SGRLyricsDrawingAurora: return @"Aurora";
        case SGRLyricsDrawingNeon: return @"Neon";
        case SGRLyricsDrawingShimmer: return @"Shimmer";
        case SGRLyricsDrawingOutline: return @"Outline";
        default: return @"Apple Music";
    }
}

void SGRSetLyricsStyle(NSString *identifier) {
    NSString *chosen = SGRLyricsStyleIDs()[SGRLyricsDrawingStyleForID(identifier)];
    void (^store)(void) = ^{
        if ([chosen isEqualToString:SGRLyricsStyleNow()]) return;
        if ([chosen isEqualToString:SGRLyricsStyleIDs().firstObject])
            [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyLyricsStyle];
        else
            [NSUserDefaults.standardUserDefaults setObject:chosen forKey:SGRKeyLyricsStyle];
        [NSNotificationCenter.defaultCenter postNotificationName:SGRLyricsStyleDidChangeNotification object:nil];
    };
    if (NSThread.isMainThread) store();
    else dispatch_async(dispatch_get_main_queue(), store);
}

UIMenu *SGRLyricsStyleMenu(NSString *title) {
    NSMutableArray<UIMenuElement *> *choices = [NSMutableArray array];
    NSString *current = SGRLyricsStyleNow();
    for (NSString *identifier in SGRLyricsStyleIDs()) {
        UIAction *action = [UIAction actionWithTitle:SGRLyricsStyleName(identifier) image:nil identifier:nil
            handler:^(UIAction *sender) { SGRSetLyricsStyle(identifier); }];
        action.state = [identifier isEqualToString:current] ? UIMenuElementStateOn : UIMenuElementStateOff;
        [choices addObject:action];
    }
    return [UIMenu menuWithTitle:title image:[UIImage systemImageNamed:@"textformat"] identifier:nil options:0 children:choices];
}
