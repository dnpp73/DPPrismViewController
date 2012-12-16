//
//  DPPrismTransition.m
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2013/01/05.
//  Copyright (c) 2013年 dnpp.org. All rights reserved.
//  参考 : https://github.com/mpospese/MPFoldTransition
//

#import "DPPrismTransition.h"
#import "DPPrismViewControllerUtils.h"
#import "DPRenderViewHelper.h"
#import <QuartzCore/QuartzCore.h>


#define DEFAULT_DURATION 0.6


static BOOL _performTransitioning = NO;
static BOOL _manualTransitioning  = NO;

static CATransform3D CATransform3DMakePerspective(CGFloat z) {
    CATransform3D t = CATransform3DIdentity;
    t.m34 = - 1.0 / z;
    return t;
}


@interface DPPrismTransition ()
{
    float _perspective;
    
    UIView* _rootView; // frontView と rightSideView と leftSideView の superview
    UIView* _frontView;
    UIView* _rightSideView;
    UIView* _leftSideView;
    
    UIView* _mainView; // この中でアニメーションをして最後に removeFromSuperview する
}
@end


@implementation DPPrismTransition

+ (NSTimeInterval)defaultDuration
{
    return DEFAULT_DURATION;
}

- (NSString*)stringFromCATransform3D:(CATransform3D)transform
{
    NSMutableString* str = [NSMutableString string];
    [str appendFormat:@"\n"];
    [str appendFormat:@"m11 = %f \t", transform.m11];
    [str appendFormat:@"m12 = %f \t", transform.m12];
    [str appendFormat:@"m13 = %f \t", transform.m13];
    [str appendFormat:@"m14 = %f \n", transform.m14];
    [str appendFormat:@"m21 = %f \t", transform.m21];
    [str appendFormat:@"m22 = %f \t", transform.m22];
    [str appendFormat:@"m23 = %f \t", transform.m23];
    [str appendFormat:@"m24 = %f \n", transform.m24];
    [str appendFormat:@"m31 = %f \t", transform.m31];
    [str appendFormat:@"m32 = %f \t", transform.m32];
    [str appendFormat:@"m33 = %f \t", transform.m33];
    [str appendFormat:@"m34 = %f \n", transform.m34];
    [str appendFormat:@"m41 = %f \t", transform.m41];
    [str appendFormat:@"m42 = %f \t", transform.m42];
    [str appendFormat:@"m43 = %f \t", transform.m43];
    [str appendFormat:@"m44 = %f \n", transform.m44];
    return str;
}

- (void)showCATransform3D:(CATransform3D)transform
{
    ShowConsole(@"%@", [self stringFromCATransform3D:transform]);
}

#pragma mark - initializer

- (id)init
{
    ShowConsole(@"指定イニシャライザを使うこと。");
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithDelegate:(id<DPPrismTransitionDelegate>)delegate
             frontView:(UIView*)frontView
         rightSideView:(UIView*)rightSideView
          leftSideView:(UIView*)leftSideView
                 sides:(NSUInteger)sides
                  type:(DPPrismTransitionType)type
            completion:(DPTransitionCompletionBlock)completion
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        
        _rootView      = frontView.superview;
        _frontView     = frontView;
        _rightSideView = rightSideView;
        _leftSideView  = leftSideView;
        _sides         = sides;
        _type          = type;
        _completion    = completion;
        
        // set default values
        _shadowColor  = [UIColor blackColor];
        _duration     = [[self class] defaultDuration];
        _timingCurve = UIViewAnimationCurveEaseInOut;
        _perspective = 700.0;
        
        _mainView = [[UIView alloc] initWithFrame:CGRectZero]; // アニメーション実行直前にリサイズしてる
        _mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _mainView.backgroundColor = [UIColor blackColor];
        _mainView.userInteractionEnabled = NO;
        _mainView.layer.sublayerTransform = CATransform3DMakePerspective(_perspective);
	}
    return self;
}

#pragma mark - Accessor

- (UIView*)frontView
{
    return _frontView;
}

- (UIView*)rightSideView
{
    return _rightSideView;
}

- (UIView*)leftSideView
{
    return _leftSideView;
}

- (float)perspective
{
    return _perspective;
}

- (void)setPerspective:(float)perspective
{
    if (_perspective != perspective) {
        _perspective  = (float)perspective;
        
        _mainView.layer.sublayerTransform = CATransform3DMakePerspective(perspective);
    }
}

- (BOOL)isPerformTransitioning
{
    return _performTransitioning;
}

- (BOOL)isManualTransitioning
{
    return _manualTransitioning;
}

#pragma mark - util

- (NSString *)timingCurveFunctionName
{
	switch (_timingCurve) {
		case UIViewAnimationCurveEaseOut:
			return kCAMediaTimingFunctionEaseOut;
			
		case UIViewAnimationCurveEaseIn:
			return kCAMediaTimingFunctionEaseIn;
			
		case UIViewAnimationCurveEaseInOut:
			return kCAMediaTimingFunctionEaseInEaseOut;
			
		case UIViewAnimationCurveLinear:
			return kCAMediaTimingFunctionLinear;
            
        default:
            return kCAMediaTimingFunctionEaseInEaseOut;
	}
	
	return kCAMediaTimingFunctionDefault;
}

#pragma mark - implementation

- (void)performTransition
{
    // インスタンスの状態チェック
    if (_performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_manualTransitioning == YES) {
        ShowConsole(@"_manualTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_rootView      == nil ||
               _mainView      == nil ||
               _frontView     == nil ||
               _rightSideView == nil ||
               _leftSideView  == nil) {
        ShowConsole(@"各種 view のいずれかが nil なのでどうしようもない。");
        return;
    } else if (!CGSizeEqualToSize(_frontView.bounds.size, _rightSideView.bounds.size) ||
               !CGSizeEqualToSize(_frontView.bounds.size, _leftSideView.bounds.size)  ||
               !CGSizeEqualToSize(_rightSideView.bounds.size, _leftSideView.bounds.size)) {
        ShowConsole(@"_frontView と _rightSideView と _leftSideView は同じサイズじゃないとダメよ。");
        return;
    }
    
    // 前準備
    _performTransitioning = YES;
    _mainView.frame = _frontView.frame;
    [_rootView addSubview:_mainView];
    
    UIView* layersView = [[UIView alloc] initWithFrame:_mainView.bounds];
    layersView.backgroundColor = _mainView.backgroundColor;
    layersView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    layersView.layer.sublayerTransform = _mainView.layer.sublayerTransform;
    [_mainView addSubview:layersView];
    
    void (^completion)(BOOL) = ^(BOOL finished){ // この段階で completion として呼ぶものを纏めておけば後でネスト出来るので
        [_mainView removeFromSuperview];
        _performTransitioning = NO;
        if ([self.delegate respondsToSelector:@selector(prismTransitionDidStopTransition:)]) {
            [self.delegate prismTransitionDidStopTransition:self];
        }
        if (_completion) {
            _completion(finished);
        }
    };
    
    BOOL clockwiseMove = (_type == DPPrismTransitionTypeClockwise);
    
    float angle = (2 * M_PI)/(float)_sides;
    
    CALayer* mainLayer;
    CALayer* frontLayer;
    CALayer* rightSideLayer;
    CALayer* leftSideLayer;
    CAGradientLayer* frontShadowLayer;
    CAGradientLayer* rightSideShadowLayer;
    CAGradientLayer* leftSideShadowLayer;
    
    { // アニメーションの下準備
        [CATransaction begin];
        [CATransaction setAnimationDuration:0];
        
        // 後で使う処理をまとめた Block (makeShadowLayer)
        __weak DPPrismTransition* w_self = self;
        CAGradientLayer* (^makeShadowLayer)(CGPoint, CGPoint) = ^(CGPoint startPoint, CGPoint endPoint){
            CAGradientLayer* shadowLayer = [CAGradientLayer layer];
            shadowLayer.colors     = (@[
                                      (id)[w_self.shadowColor colorWithAlphaComponent:0.3].CGColor,
                                      (id)w_self.shadowColor.CGColor,
                                      ]);
            shadowLayer.startPoint = startPoint;
            shadowLayer.endPoint   = endPoint;
            return shadowLayer;
        };
        
        UIImage* frontImage     = [DPRenderViewHelper renderImageFromView:_frontView];
        UIImage* rightSideImage = [DPRenderViewHelper renderImageFromView:_rightSideView];
        UIImage* leftSideImage  = [DPRenderViewHelper renderImageFromView:_leftSideView];
        
        { // mainLayer
            mainLayer = layersView.layer;
            // これやらないと Retina にならない
            mainLayer.contentsScale      = [UIScreen mainScreen].scale;
            mainLayer.rasterizationScale = [UIScreen mainScreen].scale;
            mainLayer.shouldRasterize    = YES;
        }
        
        { // frontLayer
            frontLayer = [CALayer layer];
            frontLayer.bounds = CGRectMake(0, 0, frontImage.size.width, frontImage.size.height);
            frontLayer.anchorPoint = CGPointMake((clockwiseMove?1.0:0.0), 0.5);
            frontLayer.position = CGPointMake((clockwiseMove?frontLayer.bounds.size.width:0.0), (frontLayer.bounds.size.height / 2.0));
            frontLayer.contents = (id)[frontImage CGImage];
            {
                CGFloat op = 1.0;
                frontLayer.opacity = op;
            }
            [mainLayer addSublayer:frontLayer];
        }
        
        { // frontShadowLayer
            frontShadowLayer = makeShadowLayer(CGPointMake(clockwiseMove?1.0:0.0, 0.5), CGPointMake(clockwiseMove?0.0:1.0, 0.5));
            [frontLayer addSublayer:frontShadowLayer];
            frontShadowLayer.opacity = 0.0;
            frontShadowLayer.frame = frontLayer.bounds;
        }
        
        { // rightSideLayer
            rightSideLayer = [CALayer layer];
            rightSideLayer.bounds = CGRectMake(0, 0, rightSideImage.size.width, rightSideImage.size.height);
            rightSideLayer.anchorPoint = CGPointMake(0.0, 0.5);
            rightSideLayer.position = CGPointMake((rightSideLayer.bounds.size.width), (rightSideLayer.bounds.size.height / 2.0));
            rightSideLayer.transform = CATransform3DMakeRotation(angle, 0.0, 1.0, 0.0);
            rightSideLayer.contents = (id)[rightSideImage CGImage];
            {
                CGFloat op = (clockwiseMove)?1.0:0.0;
                rightSideLayer.opacity = op;
            }
            [mainLayer addSublayer:rightSideLayer];
        }
        
        { // rightSideShadowLayer
            rightSideShadowLayer = makeShadowLayer(CGPointMake(0.0, 0.5), CGPointMake(1.0, 0.5));
            [rightSideLayer addSublayer:rightSideShadowLayer];
            rightSideShadowLayer.opacity = 1.0;
            rightSideShadowLayer.frame = rightSideLayer.bounds;
        }
        
        { // leftSideLayer
            leftSideLayer = [CALayer layer];
            leftSideLayer.bounds = CGRectMake(0, 0, leftSideImage.size.width, leftSideImage.size.height);
            leftSideLayer.anchorPoint = CGPointMake(1.0, 0.5);
            leftSideLayer.position = CGPointMake(0.0, (leftSideLayer.bounds.size.height / 2.0));
            leftSideLayer.transform = CATransform3DMakeRotation(angle, 0.0, -1.0, 0.0);
            leftSideLayer.contents = (id)[leftSideImage CGImage];
            {
                CGFloat op = (clockwiseMove)?0.0:1.0;
                leftSideLayer.opacity = op;
            }
            [mainLayer addSublayer:leftSideLayer];
        }
        
        { // leftSideShadowLayer
            leftSideShadowLayer = makeShadowLayer(CGPointMake(1.0, 0.5), CGPointMake(0.0, 0.5));
            [leftSideLayer addSublayer:leftSideShadowLayer];
            leftSideShadowLayer.opacity = 1.0;
            leftSideShadowLayer.frame = leftSideLayer.bounds;
        }
        
        [CATransaction commit];
    }
    
    { // アニメーション
        [CATransaction begin];
        [CATransaction setAnimationDuration:self.duration];
        [CATransaction setValue:[CAMediaTimingFunction functionWithName:[self timingCurveFunctionName]] forKey:kCATransactionAnimationTimingFunction];
        [CATransaction setCompletionBlock:^{
            completion(YES);
        }];
        
        [frontLayer addAnimation:(^{
            // 回転させながら
            CABasicAnimation* rotateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
            rotateAnimation.toValue = [NSNumber numberWithFloat:(angle*(clockwiseMove?-1:1))];
            
            // 動かす
            CABasicAnimation* translateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
            float moveX = (clockwiseMove?(-frontLayer.bounds.size.width):(frontLayer.bounds.size.width));
            translateAnimation.toValue  = [NSNumber numberWithFloat:moveX];
            
            // それらを放り込んで終わり
            CAAnimationGroup* animationGroup = [CAAnimationGroup animation];
            animationGroup.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.animations = @[rotateAnimation, translateAnimation];
            return animationGroup;
        }()) forKey:nil];
        
        [frontShadowLayer addAnimation:(^{
            // 影の透明度
            CABasicAnimation* opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            opacityAnimation.toValue = [NSNumber numberWithFloat:1.0];
            opacityAnimation.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            opacityAnimation.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            return opacityAnimation;
        }()) forKey:nil];
        
        [rightSideLayer addAnimation:(^{
            // 回転させながら
            CABasicAnimation* rotateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
            float f = (_sides > 3)?0:M_PI;
            rotateAnimation.toValue = [NSNumber numberWithFloat:f];
            
            // 動かす
            CABasicAnimation* translateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
            float moveX = -rightSideLayer.bounds.size.width;
            translateAnimation.toValue  = [NSNumber numberWithFloat:moveX];
            
            // それらを放り込んで終わり
            CAAnimationGroup* animationGroup = [CAAnimationGroup animation];
            animationGroup.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.animations = @[rotateAnimation, translateAnimation];
            return animationGroup;
        }()) forKey:nil];
        
        [rightSideShadowLayer addAnimation:(^{
            // 影の透明度
            CABasicAnimation* opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            opacityAnimation.toValue = [NSNumber numberWithFloat:0.0];
            opacityAnimation.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            opacityAnimation.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            return opacityAnimation;
        }()) forKey:nil];
        
        [leftSideLayer addAnimation:(^{
            // 回転させながら
            CABasicAnimation* rotateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
            float f = (_sides > 3)?0:M_PI;
            rotateAnimation.toValue = [NSNumber numberWithFloat:-f];
            
            // 動かす
            CABasicAnimation* translateAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
            float moveX = leftSideLayer.bounds.size.width;
            translateAnimation.toValue  = [NSNumber numberWithFloat:moveX];
            
            // それらを放り込んで終わり
            CAAnimationGroup* animationGroup = [CAAnimationGroup animation];
            animationGroup.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            animationGroup.animations = @[rotateAnimation, translateAnimation];
            return animationGroup;
        }()) forKey:nil];
        
        [leftSideShadowLayer addAnimation:(^{
            // 影の透明度
            CABasicAnimation* opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            opacityAnimation.toValue = [NSNumber numberWithFloat:0.0];
            opacityAnimation.removedOnCompletion = NO;       // アニメーションが終わって一瞬元に戻ってちらつくの防止
            opacityAnimation.fillMode = kCAFillModeForwards; // アニメーションが終わって一瞬元に戻ってちらつくの防止
            return opacityAnimation;
        }()) forKey:nil];
        
        [CATransaction commit];
    }
    
    // 適切なタイミングで view(?:Will|Did)(?:Disa|A)?ppear が呼ばれるように…
    [UIView animateWithDuration:self.duration
                     animations:^{
                         [_rootView insertSubview:(clockwiseMove?_rightSideView:_leftSideView) atIndex:0];
                         [_frontView removeFromSuperview];
                     }];
    
    if ([self.delegate respondsToSelector:@selector(prismTransitionDidStartTransition:)]) {
        [self.delegate prismTransitionDidStartTransition:self];
    }
}

//- (void)cancelTransition
//{
//    if (_performTransitioning == YES || _manualTransitioning == YES) {
//        _performTransitioning = NO;
//        _manualTransitioning  = NO;
//        [_mainView removeFromSuperview];
//        [_frontView removeFromSuperview];
//        [_rightSideView removeFromSuperview];
//        [_leftSideView removeFromSuperview];
//        
//        if ([self.delegate respondsToSelector:@selector(prismTransition:didStopTransitionWithCanceled:)]) {
//            [self.delegate prismTransition:self didStopTransitionWithCanceled:YES];
//        }
//        if (_completion) {
//            _completion(NO);
//        }
//    }
//}

- (void)beginTransitioning
{
    // インスタンスの状態チェック
    if (_performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_manualTransitioning == YES) {
        ShowConsole(@"_manualTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_rootView      == nil ||
               _mainView      == nil ||
               _frontView     == nil ||
               _rightSideView == nil ||
               _leftSideView  == nil) {
        ShowConsole(@"各種 view のいずれかが nil なのでどうしようもない。");
        return;
    } else if (!CGSizeEqualToSize(_frontView.bounds.size, _rightSideView.bounds.size) ||
               !CGSizeEqualToSize(_frontView.bounds.size, _leftSideView.bounds.size)  ||
               !CGSizeEqualToSize(_rightSideView.bounds.size, _leftSideView.bounds.size)) {
        ShowConsole(@"_frontView と _rightSideView と _leftSideView は同じサイズじゃないとダメよ。");
        return;
    }
    
    // 前準備
    _manualTransitioning = YES;
    
    // ToDo : 後で書く
    [self setTransitioningProgress:0.0];
    
    if ([self.delegate respondsToSelector:@selector(prismTransitionDidStartTransition:)]) {
        [self.delegate prismTransitionDidStartTransition:self];
    }
}

- (void)setTransitioningProgress:(CGFloat)transitioningProgress
{
    // インスタンスの状態チェック
    if (_manualTransitioning == NO) {
        ShowConsole(@"_manualTransitioning が NO なので transition が始まってない。");
        return;
    } else if (_performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    }
    
    // 引数チェック
    if (transitioningProgress < 0.0) {
        transitioningProgress = 0.0;
    } else if (1.0 < transitioningProgress) {
        transitioningProgress = 1.0;
    }
    
    // ToDo : 後で書く
    ShowConsole(@"%f", transitioningProgress);
}

- (void)endTransitioning
{
    // インスタンスの状態チェック
    if (_manualTransitioning == NO) {
        ShowConsole(@"_manualTransitioning が NO なので transition が始まってない。");
        return;
    } else if (_performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    }
    
    // ToDo : 後で書く
    if ([self.delegate respondsToSelector:@selector(prismTransitionDidStopTransition:)]) {
        [self.delegate prismTransitionDidStopTransition:self];
    }
}

@end
