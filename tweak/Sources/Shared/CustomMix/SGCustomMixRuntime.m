#import "SGCustomMixRuntime.h"
#import "SGCustomMixStore.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/AutoMix/SGTransitionFacts.h"
#import "Core/SGCore.h"
#include <math.h>
#include <mach/mach_time.h>

static uint64_t nanosNow(void) {
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&tb); });
    return mach_absolute_time() * tb.numer / tb.denom;
}

static double clamp01(double v) {
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
}

@interface SGCustomMixRuntime () <SGPlayerStateObserver>
@property (nonatomic, strong, nullable) SGCustomMixRule *rule;
@property (nonatomic, copy, nullable) NSString *activeFromURI;
@property (nonatomic, copy, nullable) NSString *activeToURI;
@property (nonatomic, copy, nullable) NSString *activeContextURI;
@property (nonatomic) double activeStart;
@property (nonatomic) double activeEnd;
@property (nonatomic) uint64_t activationID;
@property (nonatomic) uint64_t handedOffActivationID;
@property (nonatomic) double sampleRate;
@property (nonatomic) BOOL started;
@end

@implementation SGCustomMixRuntime {
    SGCustomMixDSPParams _params;
    SGCustomMixDSPState _state;
}

+ (instancetype)shared {
    static SGCustomMixRuntime *runtime;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ runtime = [SGCustomMixRuntime new]; });
    return runtime;
}

- (instancetype)init {
    if ((self = [super init])) {
        SGCustomMixDSPParamsInit(&_params);
        SGCustomMixDSPStateInit(&_state);
        _sampleRate = 44100.0;
    }
    return self;
}

- (SGCustomMixDSPParams *)params { return &_params; }
- (SGCustomMixDSPState *)state { return &_state; }
- (SGCustomMixRule *)activeRule { return _rule; }
- (double)progress { return _state.progress; }

- (void)start {
    if (_started) return;
    _started = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(transitionChanged:) name:SGAutoMixTransitionDidChangeNotification object:nil];
    SGAddPlayerStateObserver(self);
    dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
}

- (void)updateForSampleRate:(double)sampleRate {
    if (sampleRate > 0) _sampleRate = sampleRate;
}

- (void)transitionChanged:(NSNotification *)note { [self refresh]; }
- (void)playerStateDidChange:(SPTPlayerState *)state { [self refresh]; }
- (void)playerStateDidReport:(SPTPlayerState *)state { [self refresh]; }

- (void)clearActive {
    _activeFromURI = nil;
    _activeToURI = nil;
    _activeContextURI = nil;
    _activeStart = 0;
    _activeEnd = 0;
    SGCustomMixDSPParamsDisable(&_params);
}

- (BOOL)isSameActivationFrom:(NSString *)from to:(NSString *)to context:(NSString *)context start:(double)start end:(double)end {
    BOOL sameFrom = (from == _activeFromURI) || [from isEqualToString:_activeFromURI ?: @""];
    BOOL sameTo = (to == _activeToURI) || [to isEqualToString:_activeToURI ?: @""];
    BOOL sameCtx = (context == _activeContextURI) || [context isEqualToString:_activeContextURI ?: @""];
    return sameFrom && sameTo && sameCtx && fabs(start - _activeStart) < 0.2 && fabs(end - _activeEnd) < 0.2;
}

- (void)handoffIfNeededForState:(SPTPlayerState *)state fromURI:(NSString *)fromURI toURI:(NSString *)toURI nextTrack:(SPTPlayerTrack *)nextTrack progress:(double)progress {
    if (progress < 1.0) return;
    if (!_rule.enabled || !_rule.hasExplicitTrigger) return;
    if (_activationID == 0 || _handedOffActivationID == _activationID) return;
    if (state.isPaused) return;
    NSString *currentFrom = SGURIString(state.track.URI);
    if (![currentFrom isEqualToString:fromURI ?: @""]) return;
    id first = [state.future isKindOfClass:NSArray.class] ? state.future.firstObject : nil;
    SPTPlayerTrack *futureTrack = [first isKindOfClass:NSClassFromString(@"SPTPlayerTrack")] ? first : nil;
    NSString *futureTo = SGURIString(futureTrack.URI);
    if (![futureTo isEqualToString:toURI ?: @""]) return;

    id<SPTPlayer> player = (id<SPTPlayer>)SGPlayer();
    if (!player) return;
    uint64_t activation = _activationID;
    _handedOffActivationID = activation;
    SGLog(@"[CustomMix] mid-song handoff from %@ to %@ at progress %.2f", fromURI, toURI, progress);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.handedOffActivationID != activation) return;
        SPTPlayerState *latest = SGPlayerState();
        NSString *latestFrom = SGURIString(latest.track.URI);
        id latestFirst = [latest.future isKindOfClass:NSArray.class] ? latest.future.firstObject : nil;
        SPTPlayerTrack *latestNext = [latestFirst isKindOfClass:NSClassFromString(@"SPTPlayerTrack")] ? latestFirst : nil;
        NSString *latestTo = SGURIString(latestNext.URI);
        if (![latestFrom isEqualToString:fromURI ?: @""] || ![latestTo isEqualToString:toURI ?: @""]) return;
        if ([player respondsToSelector:@selector(skipToNextTrackWithOptions:track:)] && nextTrack) {
            [player skipToNextTrackWithOptions:nil track:nextTrack];
        } else if ([player respondsToSelector:@selector(skipToNextTrackWithOptions:)]) {
            [player skipToNextTrackWithOptions:nil];
        } else if ([player respondsToSelector:@selector(skipToNextTrack)]) {
            [player skipToNextTrack];
        }
    });
}

- (void)refresh {
    SPTPlayerState *state = SGPlayerState();
    if (!state) { [self clearActive]; self.rule = nil; return; }
    id first = [state.future isKindOfClass:NSArray.class] ? state.future.firstObject : nil;
    SPTPlayerTrack *next = [first isKindOfClass:NSClassFromString(@"SPTPlayerTrack")] ? first : nil;
    NSString *fromURI = SGURIString(state.track.URI);
    NSString *toURI = SGURIString(next.URI);
    NSString *contextURI = SGURIString(state.contextURI);
    SGCustomMixRule *rule = [[SGCustomMixStore shared] effectiveRuleForFromURI:fromURI toURI:toURI contextURI:contextURI];
    self.rule = rule;
    if (!rule.enabled || !fromURI.length || !toURI.length) {
        [self clearActive];
        return;
    }

    double pos = state.position;
    double trackDuration = state.duration;
    double duration = rule.durationSeconds > 0 ? rule.durationSeconds : 8.0;
    double start = 0;
    double end = 0;
    BOOL active = NO;

    if (rule.hasExplicitTrigger) {
        double triggerPos = [rule triggerPositionForTrackDuration:trackDuration];
        if (trackDuration > 0) triggerPos = fmin(triggerPos, fmax(0.0, trackDuration - 0.25));
        start = triggerPos;
        end = start + duration;
        if (trackDuration > 0) end = fmin(end, trackDuration);
        if (end > start && pos >= start - 0.25 && pos <= end + 0.25) active = YES;
    } else {
        SGTransitionFacts *facts = SGAutoMixCurrentTransition();
        if (facts && facts.timesKnown && facts.outEnd > facts.outStart) {
            start = facts.outStart;
            end = facts.outEnd;
            if (end > start && pos >= start - 0.25 && pos <= end + 0.25) active = YES;
        }
    }

    if (!active) {
        if (_activeFromURI.length && (![fromURI isEqualToString:_activeFromURI] || ![toURI isEqualToString:_activeToURI ?: @""])) {
            [self clearActive];
        } else if (_activeFromURI.length && pos < _activeStart - 1.0) {
            [self clearActive];
        } else {
            SGCustomMixDSPParamsDisable(&_params);
        }
        return;
    }

    double window = end - start;
    if (window <= 0) { [self clearActive]; return; }
    if (![self isSameActivationFrom:fromURI to:toURI context:contextURI start:start end:end]) {
        _activationID += 1;
        _activeFromURI = [fromURI copy];
        _activeToURI = [toURI copy];
        _activeContextURI = [contextURI copy];
        _activeStart = start;
        _activeEnd = end;
    }

    double progress = clamp01((pos - start) / window);
    uint64_t now = nanosNow();
    uint64_t durationNanos = (uint64_t)(window * 1000000000.0);
    uint64_t startNanos = now - (uint64_t)(progress * (double)durationNanos);
    uint64_t endNanos = startNanos + durationNanos;
    SGCustomMixDSPParamsSetRule(&_params, rule, _sampleRate, startNanos, endNanos);
    _state.progress = (float)progress;

    [self handoffIfNeededForState:state fromURI:fromURI toURI:toURI nextTrack:next progress:progress];
}

@end