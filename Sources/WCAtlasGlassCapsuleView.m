#import "WCAtlasGlassCapsuleView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface WCAtlasGlassCapsuleView ()
@property (nonatomic, strong, readwrite) UIVisualEffectView *effectView;
@property (nonatomic, strong, readwrite) UIView *contentView;
@property (nonatomic, strong) UIView *liquidShadeView;
@property (nonatomic, strong) CAGradientLayer *liquidBodyLayer;
@property (nonatomic, strong) CAGradientLayer *liquidRimLayer;
@property (nonatomic, strong) CAShapeLayer *liquidRimMask;
@property (nonatomic, strong) UIViewPropertyAnimator *blurAnimator;
@property (nonatomic, assign) CGFloat appliedBlurIntensity;
@property (nonatomic, assign) NSInteger appliedGlassStyle;
@end

@implementation WCAtlasGlassCapsuleView

- (void)invalidateBlurAnimator {
    UIViewPropertyAnimator *animator = self.blurAnimator;
    if (!animator) return;
    if (animator.state == UIViewAnimatingStateActive) {
        [animator stopAnimation:NO];
    }
    if (animator.state == UIViewAnimatingStateStopped) {
        [animator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
    }
    self.blurAnimator = nil;
}

- (void)dealloc {
    [self invalidateBlurAnimator];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    _appliedBlurIntensity = -1.0;
    _appliedGlassStyle = -1;

    _effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
    _effectView.userInteractionEnabled = NO;
    _effectView.clipsToBounds = YES;
    _effectView.layer.borderWidth = 0.5;
    [self addSubview:_effectView];

    _liquidShadeView = [UIView new];
    _liquidShadeView.userInteractionEnabled = NO;
    _liquidShadeView.clipsToBounds = YES;
    [self addSubview:_liquidShadeView];

    _liquidBodyLayer = [CAGradientLayer layer];
    _liquidBodyLayer.startPoint = CGPointMake(0.5, 0.0);
    _liquidBodyLayer.endPoint = CGPointMake(0.5, 1.0);
    [_liquidShadeView.layer addSublayer:_liquidBodyLayer];

    _liquidRimLayer = [CAGradientLayer layer];
    _liquidRimLayer.startPoint = CGPointMake(0.0, 0.0);
    _liquidRimLayer.endPoint = CGPointMake(1.0, 1.0);
    _liquidRimMask = [CAShapeLayer layer];
    _liquidRimMask.fillRule = kCAFillRuleEvenOdd;
    _liquidRimLayer.mask = _liquidRimMask;

    _contentView = [UIView new];
    _contentView.backgroundColor = UIColor.clearColor;
    [self addSubview:_contentView];
    [self.layer addSublayer:_liquidRimLayer];

    [self applyTraitColors];
    return self;
}

- (void)rebuildBlurEffect {
    [self invalidateBlurAnimator];
    self.effectView.alpha = 1.0;
    self.effectView.effect = nil;

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    __weak typeof(self) weakSelf = self;
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:1.0
        curve:UIViewAnimationCurveLinear
        animations:^{
            weakSelf.effectView.effect = effect;
        }];
    [animator startAnimation];
    [animator pauseAnimation];
    animator.fractionComplete = self.appliedBlurIntensity;
    self.blurAnimator = animator;
}

- (void)configureGlassWithBlurIntensity:(CGFloat)blurIntensity style:(NSInteger)style {
    CGFloat intensity = MIN(1.0, MAX(0.20, blurIntensity));
    if (fabs(self.appliedBlurIntensity - intensity) < 0.001 &&
        self.appliedGlassStyle == style) return;

    self.appliedBlurIntensity = intensity;
    self.appliedGlassStyle = style;
    // Interpolate the material itself so this setting changes the sampled
    // backdrop blur instead of merely fading the finished glass surface.
    [self rebuildBlurEffect];
    BOOL pseudoLiquid = style == 1;
    self.effectView.layer.borderWidth = pseudoLiquid ? 0.0 : 0.5;
    self.liquidShadeView.hidden = !pseudoLiquid;
    self.liquidRimLayer.hidden = !pseudoLiquid;
    self.layer.shadowOpacity = 0.0;
    self.layer.shadowPath = nil;
    [self applyTraitColors];
}

- (void)configureFrostedGlassWithBlurIntensity:(CGFloat)blurIntensity {
    [self configureGlassWithBlurIntensity:blurIntensity style:0];
}

- (void)configurePseudoLiquidWithBlurIntensity:(CGFloat)blurIntensity {
    [self configureGlassWithBlurIntensity:blurIntensity style:1];
}

- (void)refreshBackdropAfterForeground {
    if (self.appliedGlassStyle < 0) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self rebuildBlurEffect];
    [CATransaction commit];
}

- (void)applyTraitColors {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    if (self.appliedGlassStyle == 1) {
        self.liquidBodyLayer.colors = dark ? @[
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.055].CGColor,
            (id)UIColor.clearColor.CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.085].CGColor,
        ] : @[
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.14].CGColor,
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.025].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.025].CGColor,
        ];
        self.liquidBodyLayer.locations = @[@0.0, @0.58, @1.0];
        self.liquidRimLayer.colors = dark ? @[
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.28].CGColor,
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.06].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.08].CGColor,
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.18].CGColor,
        ] : @[
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.50].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.045].CGColor,
            (id)[UIColor.blackColor colorWithAlphaComponent:0.09].CGColor,
            (id)[UIColor.whiteColor colorWithAlphaComponent:0.38].CGColor,
        ];
        self.liquidRimLayer.locations = @[@0.0, @0.38, @0.72, @1.0];
    } else {
        self.effectView.layer.borderColor = (dark
            ? [UIColor.whiteColor colorWithAlphaComponent:0.14]
            : [UIColor.blackColor colorWithAlphaComponent:0.10]).CGColor;
    }
}

- (void)updateCapsuleGeometry {
    CGRect bounds = self.bounds;
    CGFloat radius = self.capsuleCornerRadius > 0.0 ? self.capsuleCornerRadius : CGRectGetHeight(bounds) * 0.5;
    self.effectView.frame = bounds;
    self.effectView.layer.cornerRadius = radius;
    self.effectView.layer.cornerCurve = kCACornerCurveContinuous;
    self.liquidShadeView.frame = bounds;
    self.liquidShadeView.layer.cornerRadius = radius;
    self.liquidShadeView.layer.cornerCurve = kCACornerCurveContinuous;
    self.liquidBodyLayer.frame = self.liquidShadeView.bounds;
    self.contentView.frame = bounds;
    self.liquidRimLayer.frame = bounds;
    CGFloat rimWidth = 0.8;
    UIBezierPath *rimPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius];
    CGRect innerBounds = CGRectInset(bounds, rimWidth, rimWidth);
    [rimPath appendPath:[UIBezierPath bezierPathWithRoundedRect:innerBounds
        cornerRadius:MAX(0.0, radius - rimWidth)]];
    self.liquidRimMask.frame = bounds;
    self.liquidRimMask.path = rimPath.CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateCapsuleGeometry];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self applyTraitColors];
    }
}

@end
