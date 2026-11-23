// PlayerState.h names the hooks and why they are the ones.
#import "Core/SGCore.h"
#import "PlayerState.h"

NSString *SGURIString(id uri) {
    if ([uri isKindOfClass:NSString.class]) return uri;
    if ([uri isKindOfClass:NSURL.class]) return ((NSURL *)uri).absoluteString;
    return nil;
}

static NSHashTable<id<SGPlayerStateObserver>> *sg_stateObservers;
static SPTPlayerState *sg_playerState;
// What the last change was told from, so a report that moved none of them tells observers nothing.
static BOOL sg_stateSeen;
static NSString *sg_stateTrack, *sg_stateContext;
static int sg_stateBits;
// Set once the now playing platform has reported; the mod's own observer on the player stands down.
static BOOL sg_platformReported = NO;

void SGAddPlayerStateObserver(id<SGPlayerStateObserver> observer) {
    if (!observer) return;
    if (!sg_stateObservers) sg_stateObservers = [NSHashTable weakObjectsHashTable];
    [sg_stateObservers addObject:observer];
}

SPTPlayerState *SGPlayerState(void) {
    return sg_playerState;
}

// The state's `future` is a plain array of id; the entries are SPTPlayerTracks with a title and a URI.
NSArray<SPTPlayerTrack *> *SGPlayerUpcomingTracks(SPTPlayerState *state, NSUInteger limit) {
    NSMutableArray<SPTPlayerTrack *> *tracks = [NSMutableArray array];
    Class trackClass = objc_getClass("SPTPlayerTrack");
    for (id item in state.future) {
        if (tracks.count == limit) break;
        if (![item isKindOfClass:trackClass]) continue;
        SPTPlayerTrack *track = (SPTPlayerTrack *)item;
        if (!track.trackTitle.length || !SGURIString(track.URI)) continue;
        [tracks addObject:track];
    }
    return tracks;
}

static BOOL sameURI(NSString *a, NSString *b) {
    return a == b || [a isEqualToString:b];
}

// What an observer is told about; the state object itself is new with every position report.
static void publish(SPTPlayerState *state) {
    sg_playerState = state;
    for (id<SGPlayerStateObserver> observer in sg_stateObservers.allObjects) {
        if ([observer respondsToSelector:@selector(playerStateDidReport:)]) [observer playerStateDidReport:state];
    }
    NSString *track = SGURIString(state.track.URI), *context = SGURIString(state.contextURI);
    SPTPlayerOptions *options = [state respondsToSelector:@selector(options)] ? state.options : nil;
    BOOL paused = state.isPaused, playing = state.isPlaying;
    BOOL loading = [state respondsToSelector:@selector(isLoading)] && state.isLoading;
    BOOL shuffling = [options respondsToSelector:@selector(shufflingContext)] && options.shufflingContext;
    int bits = paused | playing << 1 | loading << 2 | shuffling << 3;
    if (sg_stateSeen && bits == sg_stateBits && sameURI(track, sg_stateTrack) && sameURI(context, sg_stateContext)) return;
    sg_stateSeen = YES;
    sg_stateTrack = track;
    sg_stateContext = context;
    sg_stateBits = bits;
    for (id<SGPlayerStateObserver> observer in sg_stateObservers.allObjects) [observer playerStateDidChange:state];
}

static void report(id state, BOOL platform) {
    if (![state isKindOfClass:objc_getClass("SPTPlayerState")]) return;
    dispatch_block_t apply = ^{
        if (platform) sg_platformReported = YES;
        else if (sg_platformReported) return;
        publish(state);
    };
    if (NSThread.isMainThread) apply();
    else dispatch_async(dispatch_get_main_queue(), apply);
}

@interface SGPlayerObserver : NSObject
@end

@implementation SGPlayerObserver
- (void)player:(id)player stateDidChange:(id)state {
    report(state, NO);
}
@end

static SGPlayerObserver *sg_ownObserver;
static __weak id sg_player;

id SGPlayer(void) {
    return sg_player;
}

%hook _TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation
- (void)player:(id)player stateDidChange:(id)state {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"player state: from %@, a %@, on the main thread %d", [player class], [state class], NSThread.isMainThread);
    });
    report(state, YES);
}
%end

// Observers are added from several threads as the app starts; the first player seen is the one
// watched, the way KaraokeSource.x takes the first player the app asks.
%hook SPTEsperantoPlayer
- (void)addPlayerObserver:(id)observer {
    %orig;
    id player = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            sg_player = player;
            sg_ownObserver = [SGPlayerObserver new];
            [(id<SPTPlayer>)player addPlayerObserver:sg_ownObserver];
            id state = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
            if (state) report(state, NO);
        });
    });
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"_TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation", @"SPTEsperantoPlayer", @"SPTPlayerState"]);
}

// SPTPlayerState has no device/locality field. Connect's own state observer supplies it.
// These selectors and the BOOL getter are present in Spotify 9.1.90's Objective-C metadata.
@protocol SGPlayerConnectLocation <NSObject>
- (BOOL)isPlayingLocally;
- (void)addStateObserver:(id)observer;
@end

NSNotificationName const SGPlayerPlaybackLocationDidChangeNotification = @"SGPlayerPlaybackLocationDidChangeNotification";
static BOOL sg_localPlayback;
static BOOL sg_reportedRemotePlayback;
static __weak id<SGPlayerConnectLocation> sg_connectManager;

BOOL SGPlayerPlaybackIsLocal(void) {
    return sg_localPlayback;
}

BOOL SGPlayerPlaybackIsRemote(void) {
    return sg_connectManager != nil && !sg_localPlayback;
}

static void updateLocation(id<SGPlayerConnectLocation> manager) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (manager != sg_connectManager) return;
        BOOL wasLocal = sg_localPlayback;
        sg_localPlayback = [manager isPlayingLocally];
        BOOL remote = SGPlayerPlaybackIsRemote();
        if (sg_localPlayback == wasLocal && remote == sg_reportedRemotePlayback) return;
        sg_reportedRemotePlayback = remote;
        [NSNotificationCenter.defaultCenter postNotificationName:SGPlayerPlaybackLocationDidChangeNotification object:nil];
    });
}

@interface SGPlayerConnectObserver : NSObject
@end
@implementation SGPlayerConnectObserver
- (void)aggregator:(id<SGPlayerConnectLocation>)aggregator didUpdateAggregatorState:(id)state {
    updateLocation(aggregator);
}
@end

static SGPlayerConnectObserver *sg_connectObserver;
%group SGPlayerConnectLocationHooks
%hook _TtC22Connect_AggregatorImpl24ConnectAggregatorManager
- (void)addStateObserver:(id)observer {
    %orig;
    if (observer == sg_connectObserver) return;
    id<SGPlayerConnectLocation> manager = (id)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sg_connectManager == manager) return;
        sg_connectManager = manager;
        if (!sg_connectObserver) sg_connectObserver = [SGPlayerConnectObserver new];
        [manager addStateObserver:sg_connectObserver];
        updateLocation(manager);
    });
}
%end
%end

%ctor {
    Class cls = NSClassFromString(@"_TtC22Connect_AggregatorImpl24ConnectAggregatorManager");
    Method local = class_getInstanceMethod(cls, @selector(isPlayingLocally));
    Method add = class_getInstanceMethod(cls, @selector(addStateObserver:));
    char type[16] = {0};
    if (local) method_getReturnType(local, type, sizeof(type));
    if (!local || !add || strcmp(type, @encode(BOOL)) ||
        method_getNumberOfArguments(local) != 2 || method_getNumberOfArguments(add) != 3) return;
    %init(SGPlayerConnectLocationHooks);
}
