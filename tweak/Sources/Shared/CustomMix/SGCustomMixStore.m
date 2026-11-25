#import "SGCustomMixStore.h"

static NSString *const kStoreFile = @"custom-mix.json";

@interface SGCustomMixStore ()
@property (nonatomic, strong) NSMutableArray<SGCustomMixRule *> *items;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

static BOOL sameURI(NSString *a, NSString *b) {
    NSString *left = a.length ? a : @"";
    NSString *right = b.length ? b : @"";
    return [left isEqualToString:right];
}

@implementation SGCustomMixStore

+ (instancetype)shared {
    static SGCustomMixStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [SGCustomMixStore new]; });
    return store;
}

- (instancetype)init {
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        _queue = dispatch_queue_create("app.vitrine.custommix.store", DISPATCH_QUEUE_SERIAL);
        [self reload];
    }
    return self;
}

- (NSString *)storePath {
    NSURL *library = [NSFileManager.defaultManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [library URLByAppendingPathComponent:@"Application Support/Vitrine" isDirectory:YES];
    return [dir URLByAppendingPathComponent:kStoreFile].path;
}

- (void)reload {
    dispatch_sync(_queue, ^{
        [self loadLocked];
    });
}

- (void)loadLocked {
    [_items removeAllObjects];
    NSString *path = [self storePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data.length) return;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *array = nil;
    if ([json isKindOfClass:NSArray.class]) array = json;
    else if ([json isKindOfClass:NSDictionary.class] && [json[@"rules"] isKindOfClass:NSArray.class]) array = json[@"rules"];
    for (id item in array) {
        SGCustomMixRule *rule = [SGCustomMixRule ruleFromDictionary:item];
        if (rule) [_items addObject:rule];
    }
}

- (void)saveLocked {
    NSString *path = [self storePath];
    NSString *dir = [path stringByDeletingLastPathComponent];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:_items.count];
    for (SGCustomMixRule *rule in _items) [array addObject:[rule dictionaryRepresentation]];
    NSDictionary *root = @{@"version": @1, @"rules": array};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (!data) return;
    NSURL *url = [NSURL fileURLWithPath:path];
    [data writeToURL:url options:NSDataWritingAtomic error:nil];
}

- (NSArray<SGCustomMixRule *> *)rules {
    __block NSArray<SGCustomMixRule *> *copy = @[];
    dispatch_sync(_queue, ^{
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:_items.count];
        for (SGCustomMixRule *rule in _items) [out addObject:[rule copy]];
        copy = out;
    });
    return copy;
}

- (void)setRules:(NSArray<SGCustomMixRule *> *)rules {
    dispatch_sync(_queue, ^{
        [_items removeAllObjects];
        for (SGCustomMixRule *rule in rules) {
            if ([rule isKindOfClass:SGCustomMixRule.class]) [_items addObject:[rule copy]];
        }
        [self saveLocked];
    });
}

- (SGCustomMixRule *)ruleForFromURI:(NSString *)fromURI toURI:(NSString *)toURI contextURI:(NSString *)contextURI {
    __block SGCustomMixRule *match = nil;
    dispatch_sync(_queue, ^{
        NSInteger best = -1;
        for (SGCustomMixRule *rule in _items) {
            if (!rule.enabled || ![rule matchesFromURI:fromURI toURI:toURI contextURI:contextURI]) continue;
            NSInteger score = (rule.fromURI.length ? 4 : 0) + (rule.toURI.length ? 2 : 0) + (rule.contextURI.length ? 1 : 0);
            if (score > best) {
                best = score;
                match = [rule copy];
            }
        }
    });
    return match;
}

- (SGCustomMixRule *)effectiveRuleForFromURI:(NSString *)fromURI toURI:(NSString *)toURI contextURI:(NSString *)contextURI {
    SGCustomMixRule *rule = [self ruleForFromURI:fromURI toURI:toURI contextURI:contextURI];
    return rule ?: [SGCustomMixRule defaultRule];
}

- (void)upsertRule:(SGCustomMixRule *)rule forFromURI:(NSString *)fromURI toURI:(NSString *)toURI contextURI:(NSString *)contextURI {
    if (![rule isKindOfClass:SGCustomMixRule.class]) return;
    dispatch_sync(_queue, ^{
        NSString *f = fromURI.length ? fromURI : @"";
        NSString *t = toURI.length ? toURI : @"";
        NSString *c = contextURI.length ? contextURI : @"";
        NSInteger idx = -1;
        for (NSInteger i = 0; i < (NSInteger)_items.count; i++) {
            SGCustomMixRule *item = _items[i];
            if (sameURI(item.fromURI, f) && sameURI(item.toURI, t) && sameURI(item.contextURI, c)) { idx = i; break; }
        }
        SGCustomMixRule *copy = [rule copy];
        copy.fromURI = fromURI.length ? fromURI : nil;
        copy.toURI = toURI.length ? toURI : nil;
        copy.contextURI = contextURI.length ? contextURI : nil;
        if (idx >= 0) _items[idx] = copy;
        else [_items insertObject:copy atIndex:0];
        [self saveLocked];
    });
}

- (void)removeRuleForFromURI:(NSString *)fromURI toURI:(NSString *)toURI contextURI:(NSString *)contextURI {
    dispatch_sync(_queue, ^{
        NSString *f = fromURI.length ? fromURI : @"";
        NSString *t = toURI.length ? toURI : @"";
        NSString *c = contextURI.length ? contextURI : @"";
        for (NSInteger i = (NSInteger)_items.count - 1; i >= 0; i--) {
            SGCustomMixRule *item = _items[i];
            if (sameURI(item.fromURI, f) && sameURI(item.toURI, t) && sameURI(item.contextURI, c)) {
                [_items removeObjectAtIndex:i];
            }
        }
        [self saveLocked];
    });
}

@end
