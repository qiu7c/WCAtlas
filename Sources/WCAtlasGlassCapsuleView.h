#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WCAtlasGlassCapsuleView : UIView
@property (nonatomic, strong, readonly) UIVisualEffectView *effectView;
@property (nonatomic, strong, readonly) UIView *contentView;
@property (nonatomic, assign) CGFloat capsuleCornerRadius;
- (void)configureFrostedGlassWithBlurIntensity:(CGFloat)blurIntensity;
- (void)configurePseudoLiquidWithBlurIntensity:(CGFloat)blurIntensity;
- (void)refreshBackdropAfterForeground;
@end

NS_ASSUME_NONNULL_END
