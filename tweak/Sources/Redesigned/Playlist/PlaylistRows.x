// Playlist redesign: the track rows on the field, the way the Music app has them -- no surface of their own,
// artwork with rounded corners, and a hairline from the text's edge between one row and the next.
//
// Tree (trees/clean/playlist/02.txt:164-247): a cell id=Playlist.ItemCell holds an Encore.ListRow painted the
// base surface, and in it Encore.ImageView 48x48 (the artwork), Track.Row.Content.Title,
// Track.Row.Content.Subtitle and, at the trailing edge, Components.UI.ContextMenuButton. The row's own paint
// is cleared here rather than left to the Kit's repaint hook, which only hears about a color when Spotify
// sets it and not when a reused cell already carries one.
//
// Spotify's type and its spacing are left alone: the row is 64pt for a title of 18pt, and a larger font of
// the Kit's would be cut off by the box the element framework measured for it.
//
// The pills over the first row (own-playlist/01.txt:33) are a cell of the list: Add, Mix, Notes, Video,
// Edit, Sort and Name & details. The row is closed up -- ListUXPlatform_LayoutKit.ListLayout gives every
// item its height, so the cell can only close up where the layout asks it how tall it wants to be -- and
// Sort and Mix are put on the â‹¯ sheet instead (PlaylistMenu.x), where the rest of the row already is. The
// cell is handed over as it lays out, so the sheet has Spotify's own buttons to fire.
//
// Not every cell of the list is a track row. Under the tracks Spotify puts the extender -- Recommended
// songs, its rows and Refresh (ListUXPlatformConsumers_PlaylistExtenderImpl) -- and its heading and its
// Refresh cell paint the base surface over the field, where the black made bands of them (device,
// trees/continuous/2.txt 2026-09-20). So the paint comes off every cell of the page, the Kit's way, and
// only the row below is a row.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Redesigned/Kit/SGRPress.h"
#import "Playlist.h"
#import "PlaylistTransition.h"
#import <objc/message.h>

// Under the text rather than the whole row, as the Music app draws it; the trailing end clears the page margin.
static const CGFloat kHairline = 0.5, kHairlineGap = 12;
static const CGFloat kMixButtonSide = 28;

static char kRowKey, kTrackRowKey, kArtKey, kArtHolderKey, kSubtitleKey, kLineKey, kToolbarKey, kMixButtonKey, kMixPairKey;

static UIView *identified(UIView *root, NSString *identifier, const void *cacheKey);
static void clearSurface(UIView *view);
static void applyHairline(UIView *row, CGFloat leading);
static UIView *artHolderIn(UIView *row);
static UIView *rowIn(UIView *cell);

@interface SGRTrackMixPair : NSObject
@property (nonatomic, copy) NSString *fromURI;
@property (nonatomic, copy) NSString *toURI;
@property (nonatomic, copy) NSString *fromName;
@property (nonatomic, copy) NSString *toName;
@property (nonatomic, copy) NSString *contextURI;
@end

@implementation SGRTrackMixPair
@end

@interface SGRTrackMixButton : UIButton
@property (nonatomic, strong) SGRTrackMixPair *pair;
@end

@implementation SGRTrackMixButton
@end

@interface SGRRowArtHolder : NSObject
@property (nonatomic, weak) UIView *view;
@end

@implementation SGRRowArtHolder
@end

static UIView *identified(UIView *root, NSString *identifier, const void *cacheKey) {
    return SGRFindByIdentifier(root, identifier, cacheKey);
}

static void clearSurface(UIView *view) {
    UIColor *color = view.backgroundColor;
    if (color && SGIsBaseSurface(color.CGColor)) view.backgroundColor = UIColor.clearColor;
}

static void applyHairline(UIView *row, CGFloat leading) {
    CALayer *line = objc_getAssociatedObject(row, &kLineKey);
    if (!line) {
        line = [CALayer layer];
        line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
        line.zPosition = 1;
        objc_setAssociatedObject(row, &kLineKey, line, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (line.superlayer != row.layer) [row.layer addSublayer:line];
    CGRect bounds = row.bounds;
    CGRect frame = CGRectMake(leading, bounds.size.height - kHairline,
                              MAX(0, bounds.size.width - leading - SGRSideMargin), kHairline);
    if (CGRectEqualToRect(line.frame, frame)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    line.frame = frame;
    [CATransaction commit];
}

// Where the artwork has no Encore.ImageView of its own (Track.Row): the holder the picture is drawn in, a private
// class of the row kit that is told by its name. Kept on the row, as the lookups by identifier are.
static UIView *artHolderIn(UIView *row) {
    SGRRowArtHolder *box = objc_getAssociatedObject(row, &kArtHolderKey);
    UIView *cached = box.view;
    if (cached && [cached isDescendantOfView:row]) return cached;
    __block UIView *found = nil;
    SGForEachView(row, ^(UIView *v) {
        if (!found && [NSStringFromClass(v.class) hasSuffix:@"ImageViewHolder"]) found = v;
    });
    if (found) {
        if (!box) {
            box = [SGRRowArtHolder new];
            objc_setAssociatedObject(row, &kArtHolderKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        box.view = found;
    }
    return found;
}

// A playlist's row is an Encore.ListRow; the songs liked by one artist have a Track.Row of the same kit.
static UIView *rowIn(UIView *cell) {
    return identified(cell, @"Encore.ListRow", &kRowKey) ?: identified(cell, @"Track.Row", &kTrackRowKey);
}

static NSString *textOfLabel(UILabel *label) {
    NSString *text = [label.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length ? text : nil;
}

static NSString *firstLabelText(UIView *root, NSString *identifier, const void *cacheKey) {
    UIView *container = identified(root, identifier, cacheKey);
    __block NSString *text = nil;
    SGForEachView(container ?: root, ^(UIView *v) {
        if (text || ![v isKindOfClass:UILabel.class]) return;
        NSString *candidate = textOfLabel((UILabel *)v);
        if (candidate.length) text = candidate;
    });
    return text;
}

static NSString *stringFromObject(id value) {
    if ([value isKindOfClass:NSString.class]) return [(NSString *)value length] ? value : nil;
    if ([value isKindOfClass:NSURL.class]) return ((NSURL *)value).absoluteString;
    return nil;
}

static NSString *uriFromObject(id obj) {
    if (!obj) return nil;
    NSString *direct = stringFromObject(obj);
    if ([direct hasPrefix:@"spotify:track:"] || [direct hasPrefix:@"spotify:episode:"]) return direct;
    if (![obj isKindOfClass:NSObject.class]) return nil;
    NSObject *o = (NSObject *)obj;
    for (NSString *selName in @[@"uri", @"URI", @"entityUri", @"entityURI", @"trackUri", @"trackURI", @"canonicalUri", @"canonicalURI"]) {
        SEL sel = NSSelectorFromString(selName);
        if (![o respondsToSelector:sel]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(o, sel);
        NSString *uri = stringFromObject(value);
        if ([uri hasPrefix:@"spotify:track:"] || [uri hasPrefix:@"spotify:episode:"]) return uri;
    }
    return nil;
}

static id modelFromResponder(UIResponder *responder) {
    for (UIResponder *r = responder; r; r = r.nextResponder) {
        if (![r isKindOfClass:NSObject.class]) continue;
        NSObject *obj = (NSObject *)r;
        for (NSString *selName in @[@"viewModel", @"model", @"entity", @"track", @"item"]) {
            SEL sel = NSSelectorFromString(selName);
            if (![obj respondsToSelector:sel]) continue;
            id value = ((id (*)(id, SEL))objc_msgSend)(obj, sel);
            if (uriFromObject(value)) return value;
        }
        NSString *uri = uriFromObject(obj);
        if (uri) return obj;
    }
    return nil;
}

static UICollectionView *collectionViewOf(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:UICollectionView.class]) return (UICollectionView *)v;
    }
    return nil;
}

static NSString *contextURIForView(UIView *view) {
    UIViewController *vc = SGRPlaylistHeaderOf(view);
    if (!vc) return nil;
    SEL controllerSel = NSSelectorFromString(@"headerController");
    SEL modelSel = NSSelectorFromString(@"defaultHeaderViewModel");
    id controller = [vc respondsToSelector:controllerSel] ? ((id (*)(id, SEL))objc_msgSend)(vc, controllerSel) : nil;
    id model = [controller respondsToSelector:modelSel] ? ((id (*)(id, SEL))objc_msgSend)(controller, modelSel) : nil;
    if ([model isKindOfClass:NSObject.class]) {
        NSObject *obj = (NSObject *)model;
        for (NSString *name in @[@"uri", @"URI", @"entityUri", @"entityURI", @"playlistUri", @"playlistURI"]) {
            SEL sel = NSSelectorFromString(name);
            if (![obj respondsToSelector:sel]) continue;
            NSString *uri = stringFromObject(((id (*)(id, SEL))objc_msgSend)(obj, sel));
            if (uri.length) return uri;
        }
    }
    return nil;
}

static SGRTrackMixPair *pairForCell(UIView *cell) {
    if (!SGCustomMixPlaylistTransitionEnabled()) return nil;
    UIView *row = rowIn(cell);
    if (!row) return nil;
    UICollectionView *collection = collectionViewOf(cell);
    if (![collection isKindOfClass:UICollectionView.class]) return nil;
    NSIndexPath *indexPath = [collection indexPathForCell:(UICollectionViewCell *)cell];
    if (!indexPath) return nil;
    NSInteger itemCount = [collection numberOfItemsInSection:indexPath.section];
    if (indexPath.item < 0 || indexPath.item + 1 >= itemCount) return nil;

    NSIndexPath *nextPath = [NSIndexPath indexPathForItem:indexPath.item + 1 inSection:indexPath.section];
    UICollectionViewCell *nextCell = [collection cellForItemAtIndexPath:nextPath];
    UIView *nextRow = nextCell ? rowIn(nextCell) : nil;
    if (!nextRow) return nil;

    NSString *fromURI = uriFromObject(modelFromResponder(cell)) ?: uriFromObject(modelFromResponder(row));
    NSString *toURI = uriFromObject(modelFromResponder(nextCell)) ?: uriFromObject(modelFromResponder(nextRow));
    if (!fromURI.length || !toURI.length || [fromURI isEqualToString:toURI]) return nil;

    SGRTrackMixPair *pair = [SGRTrackMixPair new];
    pair.fromURI = fromURI;
    pair.toURI = toURI;
    pair.fromName = firstLabelText(row, @"Track.Row.Content.Title", NULL) ?: @"Current track";
    pair.toName = firstLabelText(nextRow, @"Track.Row.Content.Title", NULL) ?: @"Next track";
    pair.contextURI = contextURIForView(cell);
    return pair;
}

static void openTransitionEditor(SGRTrackMixButton *button) {
    SGRTrackMixPair *pair = button.pair;
    if (!pair.fromURI.length || !pair.toURI.length) return;
    SGCustomMixPresentTransitionEditor(button, pair.fromURI, pair.fromName, pair.toURI, pair.toName, pair.contextURI);
}

static void applyMixButton(UIView *cell, UIView *row) {
    SGRTrackMixButton *button = objc_getAssociatedObject(cell, &kMixButtonKey);
    SGRTrackMixPair *pair = row ? pairForCell(cell) : nil;
    if (!pair) {
        button.hidden = YES;
        objc_setAssociatedObject(cell, &kMixPairKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!button) {
        button = [SGRTrackMixButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectZero;
        button.tintColor = UIColor.whiteColor;
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        button.layer.cornerRadius = kMixButtonSide / 2.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        UIImage *img = [UIImage systemImageNamed:@"slider.horizontal.2.square"];
        if (!img) img = [UIImage systemImageNamed:@"waveform"];
        [button setImage:img forState:UIControlStateNormal];
        [button addTarget:button action:@selector(sgr_noop) forControlEvents:UIControlEventTouchUpInside];
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [button addTarget:button action:@selector(sgr_openTransition) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(cell, &kMixButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell addSubview:button];
    }

    if (![button.superview isEqual:cell]) [cell addSubview:button];
    button.pair = pair;
    objc_setAssociatedObject(cell, &kMixPairKey, pair, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *menu = identified(row, @"Components.UI.ContextMenuButton", NULL);
    CGRect menuFrame = menu ? [cell convertRect:menu.bounds fromView:menu] : CGRectZero;
    CGFloat x = menu ? CGRectGetMinX(menuFrame) - kMixButtonSide - 8 : cell.bounds.size.width - SGRSideMargin - kMixButtonSide;
    CGFloat y = menu ? CGRectGetMidY(menuFrame) - kMixButtonSide / 2.0 : (cell.bounds.size.height - kMixButtonSide) / 2.0;
    button.frame = CGRectMake(x, y, kMixButtonSide, kMixButtonSide);
    button.hidden = NO;
    button.accessibilityLabel = @"Set transition point";
}

@implementation SGRTrackMixButton (Action)
- (void)sgr_noop {}
- (void)sgr_openTransition { openTransitionEditor(self); }
@end

// YES when the cell holds a track row.
static BOOL applyRow(UIView *cell) {
    clearSurface(cell);
    UIView *row = rowIn(cell);
    // The Music app's highlight under the finger (SGRPress.h), on the rows only: not the pills or a heading.
    SGRPressRow(cell, row != nil);
    if (!row) {
        applyMixButton(cell, nil);
        return NO;
    }
    clearSurface(row);

    CGFloat leading = SGRSideMargin + 48 + kHairlineGap;
    UIView *art = identified(row, @"Encore.ImageView", &kArtKey) ?: artHolderIn(row);
    if (art) {
        if (art.layer.cornerRadius != SGRRadiusThumb) {
            art.layer.cornerRadius = SGRRadiusThumb;
            art.layer.cornerCurve = kCACornerCurveContinuous;
            art.clipsToBounds = YES;
        }
        CGRect frame = [row convertRect:art.bounds fromView:art];
        if (frame.size.width > 0) leading = CGRectGetMaxX(frame) + kHairlineGap;
    }

    UIView *subtitle = identified(row, @"Track.Row.Content.Subtitle", &kSubtitleKey);
    SGForEachView(subtitle, ^(UIView *v) {
        if (![v isKindOfClass:UILabel.class]) return;
        UILabel *label = (UILabel *)v;
        if (![label.textColor isEqual:SGRSecondary()]) label.textColor = SGRSecondary();
    });

    applyHairline(row, leading);
    applyMixButton(cell, row);
    return YES;
}

%hook _TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell
- (void)layoutSubviews {
    %orig;
    UIView *cell = (UIView *)self;
    if (!SGRPlaylistHeaderOf(cell)) return;
    SGRClearCellPaint(cell);
    // A track row is not the curation row, so only the other cells are searched for its toolbar.
    if (!applyRow(cell)) SGRPlaylistTakeCuration(cell);
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    if (!SGRFindByIdentifier((UIView *)self, SGRPlaylistCurationIdentifier, &kToolbarKey)) return result;
    result.size = CGSizeMake(result.size.width, 0);
    ((UIView *)self).clipsToBounds = YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"redesign playlist: curation pills asked for a height, answered 0"); });
    return result;
}
%end

// The rows of the songs liked by one artist are another cell (a UITableView's, Track.Row painted the base surface)
// with the same row kit in it, so they get the playlist's row: no paint, rounded artwork, the hairline.
%hook SPTEncoreSwipeableTableViewCell
- (void)layoutSubviews {
    %orig;
    UIView *cell = (UIView *)self;
    if (!sgr_playlistRoot || !SGIsInside(cell, sgr_playlistRoot)) return;
    SGRClearCellPaint(cell);
    applyRow(cell);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell", @"SPTEncoreSwipeableTableViewCell"]);
}
