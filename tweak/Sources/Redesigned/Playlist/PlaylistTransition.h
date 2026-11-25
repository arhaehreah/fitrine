#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

BOOL SGCustomMixPlaylistTransitionEnabled(void);
UIViewController * _Nullable SGCustomMixTransitionEditor(NSString *fromURI,
                                                         NSString * _Nullable fromName,
                                                         NSString *toURI,
                                                         NSString * _Nullable toName,
                                                         NSString * _Nullable contextURI);
void SGCustomMixPresentTransitionEditor(UIView *sourceView,
                                        NSString *fromURI,
                                        NSString * _Nullable fromName,
                                        NSString *toURI,
                                        NSString * _Nullable toName,
                                        NSString * _Nullable contextURI);

NS_ASSUME_NONNULL_END