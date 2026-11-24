#import "SGCustomMixRuntime.h"
#import "SGCustomMixStore.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/AutoMix/SGTransitionFacts.h"
#import "Core/SGCore.h"
#include <math.h>
#include <mach/mach_time.h>

@interface SGCustomMixRuntime () <SGPlayerStateObserver>
@property (nonatomic, strong, nullable) SGCustomMixRule *rule;
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

- (SGCustomMixDSPParams *)params {
    return &_params;
}

- (SGCustomMixDSPState *)state {
    return &_state;
}

- (SGCustomMixRule *)activeRule {
    return _rule;
}

- (double)progress {
    return _state.progress;
}

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

- (void)transitionChanged:(NSNotification *)note {
    [self refresh];
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    [self refresh];
}

- (void)playerStateDidReport:(SPTPlayerState *)state {
    // Position-only reports can activate a transition window.
    [self refresh];
}

- (void)refresh {
    SPTPlayerState *state = SGPlayerState();
    id first = [state.future isKindOfClass:NSArray.class] ? state.future.firstObject : nil;
    SPTPlayerTrack *next = [first isKindOfClass:NSClassFromString(@"SPTPlayerTrack")] ? first : nil;
    NSString *fromURI = SGURIString(state.track.URI);
    NSString *toURI = SGURIString(next.URI);
    NSString *contextURI = SGURIString(state.contextURI);
    SGCustomMixRule *rule = [[SGCustomMixStore shared] effectiveRuleForFromURI:fromURI toURI:toURI contextURI:contextURI];
    self.rule = rule;
    if (!rule.enabled) {
        SGCustomMixDSPParamsDisable(&_params);
        return;
    }

    SGTransitionFacts *facts = SGAutoMixCurrentTransition();
    double duration = rule.durationSeconds > 0 ? rule.durationSeconds : 8.0;
    double progress = 0;
    BOOL active = NO;
    if (facts && facts.timesKnown && facts.outEnd > facts.outStart) {
        double pos = state.position;
        double outStart = facts.outStart;
        double outEnd = facts.outEnd;
        double window = outEnd - outStart;
        if (window > 0 && pos >= outStart - 0.25 && pos <= outEnd + 0.25) {
            active = YES;
            duration = window;
            progress = (pos - outStart) / window;
        }
    }
    if (!active) {
        SGCustomMixDSPParamsDisable(&_params);
        return;
    }
    progress = fmax(0.0, fmin(progress, 1.0));
    uint64_t now = mach_absolute_time();
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&tb); });
    uint64_t nowNanos = now * tb.numer / tb.denom;
    uint64_t durationNanos = (uint64_t)(duration * 1000000000.0);
    uint64_t startNanos = nowNanos - (uint64_t)(progress * (double)durationNanos);
    uint64_t endNanos = startNanos + durationNanos;
    SGCustomMixDSPParamsSetRule(&_params, rule, _sampleRate, startNanos, endNanos);
}

@end
