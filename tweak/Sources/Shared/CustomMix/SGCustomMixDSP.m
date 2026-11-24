#import "SGCustomMixDSP.h"
#include <math.h>
#include <stdatomic.h>
#include <string.h>

static inline uint32_t fbits(float f) {
    uint32_t u;
    memcpy(&u, &f, sizeof(u));
    return u;
}

static inline float ffrombits(uint32_t u) {
    float f;
    memcpy(&f, &u, sizeof(f));
    return f;
}

static inline float clampf(float value, float min, float max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}


void SGCustomMixDSPParamsInit(SGCustomMixDSPParams *params) {
    if (!params) return;
    atomic_store_explicit(&params->enabled, 0, memory_order_relaxed);
    atomic_store_explicit(&params->curveType, SGCustomMixCurveEqualPower, memory_order_relaxed);
    atomic_store_explicit(&params->filterMode, SGCustomMixFilterOff, memory_order_relaxed);
    atomic_store_explicit(&params->sampleRateBits, fbits(44100.0f), memory_order_relaxed);
    atomic_store_explicit(&params->durationMs, 8000, memory_order_relaxed);
    atomic_store_explicit(&params->eqLowBits, fbits(0), memory_order_relaxed);
    atomic_store_explicit(&params->eqMidBits, fbits(0), memory_order_relaxed);
    atomic_store_explicit(&params->eqHighBits, fbits(0), memory_order_relaxed);
    atomic_store_explicit(&params->filterStartBits, fbits(20000.0f), memory_order_relaxed);
    atomic_store_explicit(&params->filterEndBits, fbits(20000.0f), memory_order_relaxed);
    atomic_store_explicit(&params->startHostNanos, 0, memory_order_relaxed);
    atomic_store_explicit(&params->endHostNanos, 0, memory_order_relaxed);
}

void SGCustomMixDSPStateInit(SGCustomMixDSPState *state) {
    if (!state) return;
    memset(state, 0, sizeof(*state));
    state->gain = 1.0f;
}

float SGCustomMixCurveValue(SGCustomMixCurve curve, float t) {
    t = clampf(t, 0.0f, 1.0f);
    switch (curve) {
        case SGCustomMixCurveEqualPower:
            return cosf(t * (float)M_PI_2);
        case SGCustomMixCurveSCurve: {
            float smooth = t * t * (3.0f - 2.0f * t);
            return 1.0f - smooth;
        }
        case SGCustomMixCurveLinear:
        default:
            return 1.0f - t;
    }
}

float SGCustomMixFilterHz(SGCustomMixFilterMode mode, float startHz, float endHz, float t) {
    t = clampf(t, 0.0f, 1.0f);
    startHz = clampf(startHz, 20.0f, 20000.0f);
    endHz = clampf(endHz, 20.0f, 20000.0f);
    if (mode == SGCustomMixFilterOff) return 20000.0f;
    return startHz + (endHz - startHz) * t;
}

static void setPassthrough(SGCustomMixBiquad *bq) {
    bq->b0 = 1.0f; bq->b1 = 0; bq->b2 = 0; bq->a1 = 0; bq->a2 = 0;
}

static void setPeaking(SGCustomMixBiquad *bq, float sampleRate, float freq, float q, float db) {
    if (fabsf(db) < 0.01f || sampleRate <= 0) { setPassthrough(bq); return; }
    float A = powf(10.0f, db / 40.0f);
    float w0 = 2.0f * (float)M_PI * clampf(freq, 20.0f, sampleRate * 0.45f) / sampleRate;
    float alpha = sinf(w0) / (2.0f * q);
    float b0 = 1.0f + alpha * A;
    float b1 = -2.0f * cosf(w0);
    float b2 = 1.0f - alpha * A;
    float a0 = 1.0f + alpha / A;
    float a1 = -2.0f * cosf(w0);
    float a2 = 1.0f - alpha / A;
    bq->b0 = b0 / a0; bq->b1 = b1 / a0; bq->b2 = b2 / a0; bq->a1 = a1 / a0; bq->a2 = a2 / a0;
}

static void setLowPass(SGCustomMixBiquad *bq, float sampleRate, float freq) {
    if (sampleRate <= 0) { setPassthrough(bq); return; }
    float w0 = 2.0f * (float)M_PI * clampf(freq, 20.0f, sampleRate * 0.45f) / sampleRate;
    float alpha = sinf(w0) / (2.0f * 0.70710678f);
    float cosw0 = cosf(w0);
    float b0 = (1.0f - cosw0) * 0.5f;
    float b1 = 1.0f - cosw0;
    float b2 = (1.0f - cosw0) * 0.5f;
    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosw0;
    float a2 = 1.0f - alpha;
    bq->b0 = b0 / a0; bq->b1 = b1 / a0; bq->b2 = b2 / a0; bq->a1 = a1 / a0; bq->a2 = a2 / a0;
}

static void setHighPass(SGCustomMixBiquad *bq, float sampleRate, float freq) {
    if (sampleRate <= 0) { setPassthrough(bq); return; }
    float w0 = 2.0f * (float)M_PI * clampf(freq, 20.0f, sampleRate * 0.45f) / sampleRate;
    float alpha = sinf(w0) / (2.0f * 0.70710678f);
    float cosw0 = cosf(w0);
    float b0 = (1.0f + cosw0) * 0.5f;
    float b1 = -(1.0f + cosw0);
    float b2 = (1.0f + cosw0) * 0.5f;
    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosw0;
    float a2 = 1.0f - alpha;
    bq->b0 = b0 / a0; bq->b1 = b1 / a0; bq->b2 = b2 / a0; bq->a1 = a1 / a0; bq->a2 = a2 / a0;
}

static inline float processBiquad(SGCustomMixBiquad *bq, float in, float *z1, float *z2) {
    float out = bq->b0 * in + *z1;
    *z1 = bq->b1 * in - bq->a1 * out + *z2;
    *z2 = bq->b2 * in - bq->a2 * out;
    return out;
}

void SGCustomMixDSPParamsSetRule(SGCustomMixDSPParams *params, SGCustomMixRule *rule, double sampleRate, uint64_t startHostNanos, uint64_t endHostNanos) {
    if (!params) return;
    if (!rule || !rule.enabled) {
        SGCustomMixDSPParamsDisable(params);
        return;
    }
    atomic_store_explicit(&params->curveType, (uint32_t)rule.curveType, memory_order_relaxed);
    atomic_store_explicit(&params->filterMode, (uint32_t)rule.filterMode, memory_order_relaxed);
    atomic_store_explicit(&params->sampleRateBits, fbits((float)sampleRate), memory_order_relaxed);
    atomic_store_explicit(&params->durationMs, (uint32_t)(rule.durationSeconds * 1000.0), memory_order_relaxed);
    atomic_store_explicit(&params->eqLowBits, fbits((float)rule.eqLowDB), memory_order_relaxed);
    atomic_store_explicit(&params->eqMidBits, fbits((float)rule.eqMidDB), memory_order_relaxed);
    atomic_store_explicit(&params->eqHighBits, fbits((float)rule.eqHighDB), memory_order_relaxed);
    atomic_store_explicit(&params->filterStartBits, fbits((float)rule.filterStartHz), memory_order_relaxed);
    atomic_store_explicit(&params->filterEndBits, fbits((float)rule.filterEndHz), memory_order_relaxed);
    atomic_store_explicit(&params->startHostNanos, startHostNanos, memory_order_relaxed);
    atomic_store_explicit(&params->endHostNanos, endHostNanos, memory_order_release);
    atomic_store_explicit(&params->enabled, 1, memory_order_release);
}

void SGCustomMixDSPParamsDisable(SGCustomMixDSPParams *params) {
    if (!params) return;
    atomic_store_explicit(&params->enabled, 0, memory_order_release);
}

void SGCustomMixDSPProcess(SGCustomMixDSPParams *params, SGCustomMixDSPState *state, uint64_t hostNanos, float *left, float *right, UInt32 frames) {
    if (!params || !state || !left || !frames) return;
    if (!atomic_load_explicit(&params->enabled, memory_order_acquire)) {
        state->gain = 1.0f;
        state->progress = 0;
        return;
    }
    uint64_t start = atomic_load_explicit(&params->startHostNanos, memory_order_relaxed);
    uint64_t end = atomic_load_explicit(&params->endHostNanos, memory_order_relaxed);
    float sampleRate = ffrombits(atomic_load_explicit(&params->sampleRateBits, memory_order_relaxed));
    if (sampleRate <= 0) sampleRate = 44100.0f;
    float t = 0;
    if (end > start) t = clampf((float)((double)(hostNanos - start) / (double)(end - start)), 0.0f, 1.0f);
    else if (hostNanos >= end && end != 0) t = 1.0f;

    SGCustomMixCurve curve = (SGCustomMixCurve)atomic_load_explicit(&params->curveType, memory_order_relaxed);
    SGCustomMixFilterMode filterMode = (SGCustomMixFilterMode)atomic_load_explicit(&params->filterMode, memory_order_relaxed);
    float eqLow = ffrombits(atomic_load_explicit(&params->eqLowBits, memory_order_relaxed));
    float eqMid = ffrombits(atomic_load_explicit(&params->eqMidBits, memory_order_relaxed));
    float eqHigh = ffrombits(atomic_load_explicit(&params->eqHighBits, memory_order_relaxed));
    float filterStart = ffrombits(atomic_load_explicit(&params->filterStartBits, memory_order_relaxed));
    float filterEnd = ffrombits(atomic_load_explicit(&params->filterEndBits, memory_order_relaxed));

    float targetGain = SGCustomMixCurveValue(curve, t);
    setPeaking(&state->low, sampleRate, 120.0f, 0.7f, eqLow);
    setPeaking(&state->mid, sampleRate, 1000.0f, 0.8f, eqMid);
    setPeaking(&state->high, sampleRate, 8000.0f, 0.7f, eqHigh);
    float filterHz = SGCustomMixFilterHz(filterMode, filterStart, filterEnd, t);
    if (filterMode == SGCustomMixFilterLowPass) setLowPass(&state->filter, sampleRate, filterHz);
    else if (filterMode == SGCustomMixFilterHighPass) setHighPass(&state->filter, sampleRate, filterHz);
    else setPassthrough(&state->filter);

    float gainStep = (targetGain - state->gain) / (float)frames;
    for (UInt32 i = 0; i < frames; i++) {
        state->gain += gainStep;
        float g = state->gain;
        float l = left[i];
        l = processBiquad(&state->low, l, &state->low.z1L, &state->low.z2L);
        l = processBiquad(&state->mid, l, &state->mid.z1L, &state->mid.z2L);
        l = processBiquad(&state->high, l, &state->high.z1L, &state->high.z2L);
        l = processBiquad(&state->filter, l, &state->filter.z1L, &state->filter.z2L);
        left[i] = l * g;
        if (right) {
            float r = right[i];
            r = processBiquad(&state->low, r, &state->low.z1R, &state->low.z2R);
            r = processBiquad(&state->mid, r, &state->mid.z1R, &state->mid.z2R);
            r = processBiquad(&state->high, r, &state->high.z1R, &state->high.z2R);
            r = processBiquad(&state->filter, r, &state->filter.z1R, &state->filter.z2R);
            right[i] = r * g;
        }
    }
    state->progress = t;
    if (t >= 1.0f) atomic_store_explicit(&params->enabled, 0, memory_order_release);
}
