#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "SGCustomMixSettings.h"
#import "SGCustomMixModel.h"
#import "SGCustomMixStore.h"

static SGCustomMixRule *defaultPreset(void) {
    SGCustomMixStore *store = [SGCustomMixStore shared];
    for (SGCustomMixRule *rule in [store rules]) {
        if (!rule.fromURI.length && !rule.toURI.length && !rule.contextURI.length) return rule;
    }
    SGCustomMixRule *rule = [SGCustomMixRule defaultRule];
    rule.enabled = YES;
    return rule;
}

static void saveDefaultPreset(SGCustomMixRule *preset) {
    SGCustomMixStore *store = [SGCustomMixStore shared];
    NSMutableArray<SGCustomMixRule *> *rules = [[store rules] mutableCopy];
    NSInteger idx = -1;
    for (NSInteger i = 0; i < (NSInteger)rules.count; i++) {
        SGCustomMixRule *rule = rules[i];
        if (!rule.fromURI.length && !rule.toURI.length && !rule.contextURI.length) { idx = i; break; }
    }
    preset.fromURI = nil; preset.toURI = nil; preset.contextURI = nil;
    if (idx >= 0) rules[idx] = preset; else [rules insertObject:preset atIndex:0];
    [store setRules:rules];
}

static NSString *curveName(SGCustomMixCurve curve) {
    switch (curve) {
        case SGCustomMixCurveEqualPower: return @"Equal power";
        case SGCustomMixCurveSCurve: return @"S-curve";
        case SGCustomMixCurveLinear:
        default: return @"Linear";
    }
}

static NSString *filterName(SGCustomMixFilterMode mode) {
    switch (mode) {
        case SGCustomMixFilterLowPass: return @"Low-pass";
        case SGCustomMixFilterHighPass: return @"High-pass";
        case SGCustomMixFilterOff:
        default: return @"Off";
    }
}

static SGModRow *dbSlider(NSString *title, double (^get)(void), void (^set)(double v), NSString *key) {
    SGModRow *row = SGSliderRow(title, nil, -12.0, 12.0, 0.5, get, set, ^NSString *(double v) {
        return [NSString stringWithFormat:@"%@%.1f dB", v > 0 ? @"+" : @"", v];
    });
    row.waitsOn = key;
    return row;
}

static SGModRow *hzSlider(NSString *title, double min, double max, double step, double (^get)(void), void (^set)(double v), NSString *key) {
    SGModRow *row = SGSliderRow(title, nil, min, max, step, get, set, ^NSString *(double v) {
        return [NSString stringWithFormat:@"%.0f Hz", v];
    });
    row.waitsOn = key;
    return row;
}

UIViewController *SGCustomMixSettingsPage(void) {
    __block SGCustomMixRule *preset = defaultPreset();
    __block __weak SGModPage *weakPage;

    SGModRow *enable = SGOptionRow(@"Custom Mix", @"Apply local transition rules over Spotify playback", SGKeyCustomMix);
    enable.changed = ^(BOOL on) {
        preset.enabled = on;
        saveDefaultPreset(preset);
        [weakPage refreshVisibility];
    };

    SGModRow *duration = SGSliderRow(@"Default duration", nil, 1.0, 30.0, 0.5,
        ^double { return preset.durationSeconds; },
        ^(double v) { preset.durationSeconds = v; saveDefaultPreset(preset); },
        ^NSString *(double v) { return [NSString stringWithFormat:@"%.1f s", v]; });
    duration.waitsOn = SGKeyCustomMix;

    NSArray<NSString *> *curves = @[@"Linear", @"Equal power", @"S-curve"];
    SGModRow *curve = SGMenuRow(@"Curve", curves, ^NSString *{ return curveName(preset.curveType); }, ^(NSInteger index) {
        preset.curveType = (SGCustomMixCurve)index;
        saveDefaultPreset(preset);
    });
    curve.waitsOn = SGKeyCustomMix;

    SGModRow *low = dbSlider(@"Low EQ", ^double { return preset.eqLowDB; }, ^(double v) { preset.eqLowDB = v; saveDefaultPreset(preset); }, SGKeyCustomMix);
    SGModRow *mid = dbSlider(@"Mid EQ", ^double { return preset.eqMidDB; }, ^(double v) { preset.eqMidDB = v; saveDefaultPreset(preset); }, SGKeyCustomMix);
    SGModRow *high = dbSlider(@"High EQ", ^double { return preset.eqHighDB; }, ^(double v) { preset.eqHighDB = v; saveDefaultPreset(preset); }, SGKeyCustomMix);

    NSArray<NSString *> *filters = @[@"Off", @"Low-pass", @"High-pass"];
    SGModRow *filter = SGMenuRow(@"Filter", filters, ^NSString *{ return filterName(preset.filterMode); }, ^(NSInteger index) {
        preset.filterMode = (SGCustomMixFilterMode)index;
        saveDefaultPreset(preset);
        [weakPage refreshVisibility];
    });
    filter.waitsOn = SGKeyCustomMix;

    SGModRow *filterStart = hzSlider(@"Filter start", 20, 20000, 100, ^double { return preset.filterStartHz; }, ^(double v) { preset.filterStartHz = v; saveDefaultPreset(preset); }, SGKeyCustomMix);
    filterStart.visible = ^BOOL { return SGFlag(SGKeyCustomMix, NO) && preset.filterMode != SGCustomMixFilterOff; };
    SGModRow *filterEnd = hzSlider(@"Filter end", 20, 20000, 100, ^double { return preset.filterEndHz; }, ^(double v) { preset.filterEndHz = v; saveDefaultPreset(preset); }, SGKeyCustomMix);
    filterEnd.visible = filterStart.visible;

    SGModRow *reset = SGActionRow(@"Reset default preset", nil, ^{
        preset = [SGCustomMixRule defaultRule];
        preset.enabled = SGFlag(SGKeyCustomMix, NO);
        saveDefaultPreset(preset);
        [weakPage.tableView reloadData];
        [weakPage refreshVisibility];
    });
    reset.waitsOn = SGKeyCustomMix;

    SGModRow *ruleCount = SGStatRow(@"Saved rules", ^{
        return [NSString stringWithFormat:@"%lu", (unsigned long)[SGCustomMixStore shared].rules.count];
    });

    SGModPage *page = [[SGModPage alloc] initWithTitle:@"Custom Mix" intro:nil sections:@[
        SGNotedSection(nil, @[enable], @"Local transition FX overlay. It does not fetch Spotify Mix server data."),
        SGSection(@"Default transition", @[duration, curve]),
        SGSection(@"EQ", @[low, mid, high]),
        SGSection(@"Filter", @[filter, filterStart, filterEnd]),
        SGSection(nil, @[reset, ruleCount]),
    ] footer:@"Applies during detected transition windows. Redesigned player only for the indicator in Milestone 2."];
    weakPage = page;
    return page;
}

NSString *SGCustomMixSummary(void) {
    return SGFlag(SGKeyCustomMix, NO) ? @"On" : @"Off";
}
