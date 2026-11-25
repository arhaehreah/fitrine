#import <Foundation/Foundation.h>
#import <math.h>
#import "Shared/CustomMix/SGCustomMixModel.h"
#import "Shared/CustomMix/SGCustomMixDSP.h"

static int failures = 0;
#define CHECK(cond, msg) do { if (!(cond)) { failures++; NSLog(@"FAIL: %@", msg); } } while (0)
#define CHECKF(a, b, eps, msg) CHECK(fabs((double)(a) - (double)(b)) <= (eps), msg)

static void testCurves(void) {
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveLinear, 0), 1.0f, 0.001, @"linear t0");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveLinear, 1), 0.0f, 0.001, @"linear t1");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveLinear, 0.5f), 0.5f, 0.001, @"linear t0.5");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveEqualPower, 0), 1.0f, 0.001, @"eqpow t0");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveEqualPower, 1), 0.0f, 0.001, @"eqpow t1");
    float mid = SGCustomMixCurveValue(SGCustomMixCurveEqualPower, 0.5f);
    CHECK(mid > 0.6f && mid < 0.8f, @"eqpow midpoint");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveSCurve, 0), 1.0f, 0.001, @"scurve t0");
    CHECKF(SGCustomMixCurveValue(SGCustomMixCurveSCurve, 1), 0.0f, 0.001, @"scurve t1");
}

static void testFilterHz(void) {
    CHECKF(SGCustomMixFilterHz(SGCustomMixFilterLowPass, 20000, 200, 0), 20000, 1, @"lp start");
    CHECKF(SGCustomMixFilterHz(SGCustomMixFilterLowPass, 20000, 200, 1), 200, 1, @"lp end");
    CHECKF(SGCustomMixFilterHz(SGCustomMixFilterHighPass, 20, 2000, 0.5f), 1010, 1, @"hp mid");
    CHECKF(SGCustomMixFilterHz(SGCustomMixFilterOff, 20, 2000, 0.5f), 20000, 1, @"off");
}

static void testBiquadStability(void) {
    SGCustomMixDSPParams params;
    SGCustomMixDSPState state;
    SGCustomMixDSPParamsInit(&params);
    SGCustomMixDSPStateInit(&state);
    SGCustomMixRule *rule = [SGCustomMixRule defaultRule];
    rule.enabled = YES;
    rule.durationSeconds = 1.0;
    rule.eqLowDB = 6.0;
    rule.eqMidDB = -3.0;
    rule.eqHighDB = 4.0;
    rule.filterMode = SGCustomMixFilterLowPass;
    rule.filterStartHz = 20000;
    rule.filterEndHz = 400;
    SGCustomMixDSPParamsSetRule(&params, rule, 44100.0, 0, 1000000000ULL);
    float left[256], right[256];
    for (int block = 0; block < 200; block++) {
        for (int i = 0; i < 256; i++) {
            float s = sinf((float)(block * 256 + i) * 0.1f);
            left[i] = s;
            right[i] = -s;
        }
        SGCustomMixDSPProcess(&params, &state, (uint64_t)block * 5000000ULL, left, right, 256);
        for (int i = 0; i < 256; i++) {
            CHECK(isfinite(left[i]) && isfinite(right[i]), @"finite output");
            CHECK(fabs(left[i]) < 10.0f && fabs(right[i]) < 10.0f, @"bounded output");
        }
    }
}

static void testRuleMatching(void) {
    SGCustomMixRule *rule = [SGCustomMixRule defaultRule];
    rule.enabled = YES;
    rule.fromURI = @"spotify:track:aaa";
    rule.toURI = @"spotify:track:bbb";
    CHECK([rule matchesFromURI:@"spotify:track:aaa" toURI:@"spotify:track:bbb" contextURI:nil], @"exact match");
    CHECK(![rule matchesFromURI:@"spotify:track:aaa" toURI:@"spotify:track:ccc" contextURI:nil], @"to mismatch");
    SGCustomMixRule *wild = [SGCustomMixRule defaultRule];
    wild.enabled = YES;
    CHECK([wild matchesFromURI:@"a" toURI:@"b" contextURI:@"c"], @"wildcard match");
}

static void testRuleRoundtrip(void) {
    SGCustomMixRule *rule = [SGCustomMixRule defaultRule];
    rule.fromURI = @"spotify:track:a";
    rule.toURI = @"spotify:track:b";
    rule.contextURI = @"spotify:playlist:p";
    rule.durationSeconds = 5.5;
    rule.curveType = SGCustomMixCurveSCurve;
    rule.eqLowDB = -2.5;
    rule.eqMidDB = 1.0;
    rule.eqHighDB = 3.5;
    rule.filterMode = SGCustomMixFilterHighPass;
    rule.filterStartHz = 40;
    rule.filterEndHz = 1200;
    rule.enabled = YES;
    rule.triggerMode = SGCustomMixTriggerPercent;
    rule.triggerValue = 50;
    NSDictionary *dict = [rule dictionaryRepresentation];
    SGCustomMixRule *decoded = [SGCustomMixRule ruleFromDictionary:dict];
    CHECK(decoded != nil, @"decoded");
    CHECK([decoded.fromURI isEqualToString:rule.fromURI], @"from");
    CHECK([decoded.toURI isEqualToString:rule.toURI], @"to");
    CHECK([decoded.contextURI isEqualToString:rule.contextURI], @"context");
    CHECKF(decoded.durationSeconds, 5.5, 0.001, @"duration");
    CHECK(decoded.curveType == SGCustomMixCurveSCurve, @"curve");
    CHECK(decoded.filterMode == SGCustomMixFilterHighPass, @"filter mode");
    CHECK(decoded.enabled == YES, @"enabled");
    CHECK(decoded.triggerMode == SGCustomMixTriggerPercent, @"trigger mode");
    CHECKF(decoded.triggerValue, 50.0, 0.001, @"trigger value");
}

static void testTriggerDefaultsAndClamps(void) {
    NSDictionary *legacy = @{ @"enabled": @YES, @"durationSeconds": @8.0 };
    SGCustomMixRule *decoded = [SGCustomMixRule ruleFromDictionary:legacy];
    CHECK(decoded != nil, @"legacy decoded");
    CHECK(decoded.triggerMode == SGCustomMixTriggerEnd, @"legacy trigger defaults to end");
    CHECKF(decoded.triggerValue, 0.0, 0.001, @"legacy trigger value default");

    SGCustomMixRule *percent = [SGCustomMixRule ruleFromDictionary:@{@"triggerMode": @(SGCustomMixTriggerPercent), @"triggerValue": @150}];
    CHECK(percent.triggerMode == SGCustomMixTriggerPercent, @"percent mode");
    CHECKF(percent.triggerValue, 100.0, 0.001, @"percent clamp");

    SGCustomMixRule *seconds = [SGCustomMixRule ruleFromDictionary:@{@"triggerMode": @(SGCustomMixTriggerSeconds), @"triggerValue": @(-5)}];
    CHECK(seconds.triggerMode == SGCustomMixTriggerSeconds, @"seconds mode");
    CHECKF(seconds.triggerValue, 0.0, 0.001, @"seconds clamp");
}

static void testTriggerPosition(void) {
    SGCustomMixRule *rule = [SGCustomMixRule defaultRule];
    rule.triggerMode = SGCustomMixTriggerPercent;
    rule.triggerValue = 50;
    CHECKF([rule triggerPositionForTrackDuration:200.0], 100.0, 0.001, @"percent midpoint");

    rule.triggerMode = SGCustomMixTriggerSeconds;
    rule.triggerValue = 42;
    CHECKF([rule triggerPositionForTrackDuration:200.0], 42.0, 0.001, @"seconds position");
    CHECKF([rule triggerPositionForTrackDuration:20.0], 20.0, 0.001, @"seconds clamp to duration");

    rule.triggerMode = SGCustomMixTriggerEnd;
    CHECK([rule triggerPositionForTrackDuration:200.0] < 0, @"end has no explicit position");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        testCurves();
        testFilterHz();
        testBiquadStability();
        testRuleMatching();
        testRuleRoundtrip();
        testTriggerDefaultsAndClamps();
        testTriggerPosition();
        if (failures) {
            NSLog(@"%d failures", failures);
            return 1;
        }
        NSLog(@"ok");
    }
    return 0;
}