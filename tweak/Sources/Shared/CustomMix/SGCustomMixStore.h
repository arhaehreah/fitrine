#import <Foundation/Foundation.h>
#import "SGCustomMixModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface SGCustomMixStore : NSObject

+ (instancetype)shared;
- (NSArray<SGCustomMixRule *> *)rules;
- (void)setRules:(NSArray<SGCustomMixRule *> *)rules;
- (nullable SGCustomMixRule *)ruleForFromURI:(nullable NSString *)fromURI toURI:(nullable NSString *)toURI contextURI:(nullable NSString *)contextURI;
- (SGCustomMixRule *)effectiveRuleForFromURI:(nullable NSString *)fromURI toURI:(nullable NSString *)toURI contextURI:(nullable NSString *)contextURI;
- (void)reload;
- (NSString *)storePath;

@end

NS_ASSUME_NONNULL_END
