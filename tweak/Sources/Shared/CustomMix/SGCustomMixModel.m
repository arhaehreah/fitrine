#import "SGCustomMixModel.h"

static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

static NSInteger clampInt(NSInteger value, NSInteger min, NSInteger max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

@implementation SGCustomMixRule

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)defaultRule {
    SGCustomMixRule *rule = [SGCustomMixRule new];
    rule.durationSeconds = 8.0;
    rule.curveType = SGCustomMixCurveEqualPower;
    rule.eqLowDB = 0;
    rule.eqMidDB = 0;
    rule.eqHighDB = 0;
    rule.filterMode = SGCustomMixFilterOff;
    rule.filterStartHz = 20000;
    rule.filterEndHz = 20000;
    rule.enabled = NO;
    rule.triggerMode = SGCustomMixTriggerEnd;
    rule.triggerValue = 0;
    return rule;
}

- (instancetype)init {
    if ((self = [super init])) {
        _durationSeconds = 8.0;
        _curveType = SGCustomMixCurveEqualPower;
        _filterStartHz = 20000;
        _filterEndHz = 20000;
        _enabled = NO;
        _triggerMode = SGCustomMixTriggerEnd;
        _triggerValue = 0;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _fromURI = [coder decodeObjectOfClass:NSString.class forKey:@"fromURI"];
        _toURI = [coder decodeObjectOfClass:NSString.class forKey:@"toURI"];
        _contextURI = [coder decodeObjectOfClass:NSString.class forKey:@"contextURI"];
        _durationSeconds = [coder decodeDoubleForKey:@"durationSeconds"];
        _curveType = (SGCustomMixCurve)[coder decodeIntegerForKey:@"curveType"];
        _eqLowDB = [coder decodeDoubleForKey:@"eqLowDB"];
        _eqMidDB = [coder decodeDoubleForKey:@"eqMidDB"];
        _eqHighDB = [coder decodeDoubleForKey:@"eqHighDB"];
        _filterMode = (SGCustomMixFilterMode)[coder decodeIntegerForKey:@"filterMode"];
        _filterStartHz = [coder decodeDoubleForKey:@"filterStartHz"];
        _filterEndHz = [coder decodeDoubleForKey:@"filterEndHz"];
        _enabled = [coder decodeBoolForKey:@"enabled"];
        _triggerMode = (SGCustomMixTriggerMode)clampInt([coder decodeIntegerForKey:@"triggerMode"], 0, 2);
        _triggerValue = [coder decodeDoubleForKey:@"triggerValue"];
        if (_triggerMode == SGCustomMixTriggerPercent) _triggerValue = clampDouble(_triggerValue, 0.0, 100.0);
        else if (_triggerMode == SGCustomMixTriggerSeconds) _triggerValue = clampDouble(_triggerValue, 0.0, 24.0 * 60.0 * 60.0);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_fromURI forKey:@"fromURI"];
    [coder encodeObject:_toURI forKey:@"toURI"];
    [coder encodeObject:_contextURI forKey:@"contextURI"];
    [coder encodeDouble:_durationSeconds forKey:@"durationSeconds"];
    [coder encodeInteger:_curveType forKey:@"curveType"];
    [coder encodeDouble:_eqLowDB forKey:@"eqLowDB"];
    [coder encodeDouble:_eqMidDB forKey:@"eqMidDB"];
    [coder encodeDouble:_eqHighDB forKey:@"eqHighDB"];
    [coder encodeInteger:_filterMode forKey:@"filterMode"];
    [coder encodeDouble:_filterStartHz forKey:@"filterStartHz"];
    [coder encodeDouble:_filterEndHz forKey:@"filterEndHz"];
    [coder encodeBool:_enabled forKey:@"enabled"];
    [coder encodeInteger:_triggerMode forKey:@"triggerMode"];
    [coder encodeDouble:_triggerValue forKey:@"triggerValue"];
}

- (id)copyWithZone:(NSZone *)zone {
    SGCustomMixRule *rule = [[[self class] allocWithZone:zone] init];
    rule.fromURI = [_fromURI copy];
    rule.toURI = [_toURI copy];
    rule.contextURI = [_contextURI copy];
    rule.durationSeconds = _durationSeconds;
    rule.curveType = _curveType;
    rule.eqLowDB = _eqLowDB;
    rule.eqMidDB = _eqMidDB;
    rule.eqHighDB = _eqHighDB;
    rule.filterMode = _filterMode;
    rule.filterStartHz = _filterStartHz;
    rule.filterEndHz = _filterEndHz;
    rule.enabled = _enabled;
    rule.triggerMode = _triggerMode;
    rule.triggerValue = _triggerValue;
    return rule;
}

- (BOOL)matchesFromURI:(NSString *)fromURI toURI:(NSString *)toURI contextURI:(NSString *)contextURI {
    if (_fromURI.length && ![_fromURI isEqualToString:fromURI ?: @""]) return NO;
    if (_toURI.length && ![_toURI isEqualToString:toURI ?: @""]) return NO;
    if (_contextURI.length && ![_contextURI isEqualToString:contextURI ?: @""]) return NO;
    return YES;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"fromURI": _fromURI ?: @"",
        @"toURI": _toURI ?: @"",
        @"contextURI": _contextURI ?: @"",
        @"durationSeconds": @(_durationSeconds),
        @"curveType": @(_curveType),
        @"eqLowDB": @(_eqLowDB),
        @"eqMidDB": @(_eqMidDB),
        @"eqHighDB": @(_eqHighDB),
        @"filterMode": @(_filterMode),
        @"filterStartHz": @(_filterStartHz),
        @"filterEndHz": @(_filterEndHz),
        @"enabled": @(_enabled),
        @"triggerMode": @(_triggerMode),
        @"triggerValue": @(_triggerValue),
    };
}

- (BOOL)hasExplicitTrigger {
    return _triggerMode == SGCustomMixTriggerSeconds || _triggerMode == SGCustomMixTriggerPercent;
}

- (double)triggerPositionForTrackDuration:(double)duration {
    if (_triggerMode == SGCustomMixTriggerSeconds) return clampDouble(_triggerValue, 0.0, duration > 0 ? duration : _triggerValue);
    if (_triggerMode == SGCustomMixTriggerPercent) {
        double pct = clampDouble(_triggerValue, 0.0, 100.0);
        if (duration <= 0) return 0;
        return clampDouble(duration * (pct / 100.0), 0.0, duration);
    }
    return -1;
}

+ (nullable instancetype)ruleFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    SGCustomMixRule *rule = [SGCustomMixRule new];
    id from = dictionary[@"fromURI"];
    id to = dictionary[@"toURI"];
    id context = dictionary[@"contextURI"];
    rule.fromURI = [from isKindOfClass:NSString.class] && [from length] ? from : nil;
    rule.toURI = [to isKindOfClass:NSString.class] && [to length] ? to : nil;
    rule.contextURI = [context isKindOfClass:NSString.class] && [context length] ? context : nil;
    rule.durationSeconds = clampDouble([dictionary[@"durationSeconds"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"durationSeconds"] doubleValue] : 8.0, 0.1, 30.0);
    rule.curveType = (SGCustomMixCurve)clampInt([dictionary[@"curveType"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"curveType"] integerValue] : SGCustomMixCurveEqualPower, 0, 2);
    rule.eqLowDB = clampDouble([dictionary[@"eqLowDB"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"eqLowDB"] doubleValue] : 0, -12.0, 12.0);
    rule.eqMidDB = clampDouble([dictionary[@"eqMidDB"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"eqMidDB"] doubleValue] : 0, -12.0, 12.0);
    rule.eqHighDB = clampDouble([dictionary[@"eqHighDB"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"eqHighDB"] doubleValue] : 0, -12.0, 12.0);
    rule.filterMode = (SGCustomMixFilterMode)clampInt([dictionary[@"filterMode"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"filterMode"] integerValue] : SGCustomMixFilterOff, 0, 2);
    rule.filterStartHz = clampDouble([dictionary[@"filterStartHz"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"filterStartHz"] doubleValue] : 20000, 20, 20000);
    rule.filterEndHz = clampDouble([dictionary[@"filterEndHz"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"filterEndHz"] doubleValue] : 20000, 20, 20000);
    rule.enabled = [dictionary[@"enabled"] respondsToSelector:@selector(boolValue)] ? [dictionary[@"enabled"] boolValue] : NO;
    rule.triggerMode = (SGCustomMixTriggerMode)clampInt([dictionary[@"triggerMode"] respondsToSelector:@selector(integerValue)] ? [dictionary[@"triggerMode"] integerValue] : SGCustomMixTriggerEnd, 0, 2);
    double triggerValue = [dictionary[@"triggerValue"] respondsToSelector:@selector(doubleValue)] ? [dictionary[@"triggerValue"] doubleValue] : 0;
    if (rule.triggerMode == SGCustomMixTriggerPercent) triggerValue = clampDouble(triggerValue, 0.0, 100.0);
    else if (rule.triggerMode == SGCustomMixTriggerSeconds) triggerValue = clampDouble(triggerValue, 0.0, 24.0 * 60.0 * 60.0);
    else triggerValue = 0;
    rule.triggerValue = triggerValue;
    return rule;
}

@end
