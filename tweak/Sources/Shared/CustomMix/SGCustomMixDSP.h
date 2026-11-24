#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SGCustomMixModel.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float b0, b1, b2, a1, a2;
    float z1L, z2L, z1R, z2R;
} SGCustomMixBiquad;

typedef struct {
    float gain;
    float progress;
    SGCustomMixBiquad low;
    SGCustomMixBiquad mid;
    SGCustomMixBiquad high;
    SGCustomMixBiquad filter;
} SGCustomMixDSPState;

typedef struct {
    _Atomic(uint32_t) enabled;
    _Atomic(uint32_t) curveType;
    _Atomic(uint32_t) filterMode;
    _Atomic(uint32_t) sampleRateBits;
    _Atomic(uint32_t) durationMs;
    _Atomic(uint32_t) eqLowBits;
    _Atomic(uint32_t) eqMidBits;
    _Atomic(uint32_t) eqHighBits;
    _Atomic(uint32_t) filterStartBits;
    _Atomic(uint32_t) filterEndBits;
    _Atomic(uint64_t) startHostNanos;
    _Atomic(uint64_t) endHostNanos;
} SGCustomMixDSPParams;

void SGCustomMixDSPParamsInit(SGCustomMixDSPParams *params);
void SGCustomMixDSPStateInit(SGCustomMixDSPState *state);
void SGCustomMixDSPParamsSetRule(SGCustomMixDSPParams *params, SGCustomMixRule *rule, double sampleRate, uint64_t startHostNanos, uint64_t endHostNanos);
void SGCustomMixDSPParamsDisable(SGCustomMixDSPParams *params);
void SGCustomMixDSPProcess(SGCustomMixDSPParams *params, SGCustomMixDSPState *state, uint64_t hostNanos, float *left, float *right, UInt32 frames);
float SGCustomMixCurveValue(SGCustomMixCurve curve, float t);
float SGCustomMixFilterHz(SGCustomMixFilterMode mode, float startHz, float endHz, float t);

#ifdef __cplusplus
}
#endif
