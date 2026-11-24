#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define SGKeyCustomMix @"spotifyglass.custommix.enabled"

typedef NS_ENUM(NSInteger, SGCustomMixCurve) {
    SGCustomMixCurveLinear = 0,
    SGCustomMixCurveEqualPower = 1,
    SGCustomMixCurveSCurve = 2,
};

typedef NS_ENUM(NSInteger, SGCustomMixFilterMode) {
    SGCustomMixFilterOff = 0,
    SGCustomMixFilterLowPass = 1,
    SGCustomMixFilterHighPass = 2,
};

@interface SGCustomMixRule : NSObject <NSSecureCoding, NSCopying>

@property (nonatomic, copy, nullable) NSString *fromURI;
@property (nonatomic, copy, nullable) NSString *toURI;
@property (nonatomic, copy, nullable) NSString *contextURI;
@property (nonatomic) double durationSeconds;
@property (nonatomic) SGCustomMixCurve curveType;
@property (nonatomic) double eqLowDB;
@property (nonatomic) double eqMidDB;
@property (nonatomic) double eqHighDB;
@property (nonatomic) SGCustomMixFilterMode filterMode;
@property (nonatomic) double filterStartHz;
@property (nonatomic) double filterEndHz;
@property (nonatomic) BOOL enabled;

+ (instancetype)defaultRule;
- (BOOL)matchesFromURI:(nullable NSString *)fromURI toURI:(nullable NSString *)toURI contextURI:(nullable NSString *)contextURI;
- (NSDictionary *)dictionaryRepresentation;
+ (nullable instancetype)ruleFromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
