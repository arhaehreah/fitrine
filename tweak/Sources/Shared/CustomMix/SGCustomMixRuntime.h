#import <Foundation/Foundation.h>
#import "SGCustomMixModel.h"
#import "SGCustomMixDSP.h"

NS_ASSUME_NONNULL_BEGIN

@interface SGCustomMixRuntime : NSObject

+ (instancetype)shared;
- (void)start;
- (SGCustomMixDSPParams *)params;
- (SGCustomMixDSPState *)state;
- (nullable SGCustomMixRule *)activeRule;
- (double)progress;
- (void)updateForSampleRate:(double)sampleRate;

@end

NS_ASSUME_NONNULL_END
