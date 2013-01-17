//
//  DPPrismTransition.h
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2013/01/05.
//  Copyright (c) 2013年 dnpp.org. All rights reserved.
//  参考 : https://github.com/mpospese/MPFoldTransition
//

#import <Foundation/Foundation.h>

typedef void (^DPTransitionCompletionBlock)(BOOL);

typedef enum {
    DPPrismTransitionTypeUndefined,
    DPPrismTransitionTypeClockwise,
    DPPrismTransitionTypeCounterclockwise,
} DPPrismTransitionType;


@protocol DPPrismTransitionDelegate;


@interface DPPrismTransition : NSObject

@property (nonatomic, readonly) UIView* frontView;
@property (nonatomic, readonly) UIView* rightSideView;
@property (nonatomic, readonly) UIView* leftSideView;
@property (nonatomic, assign)   NSUInteger sides;
@property (nonatomic, readonly) DPPrismTransitionType type;
@property (nonatomic, strong)   DPTransitionCompletionBlock completion;

@property (nonatomic, weak) id<DPPrismTransitionDelegate> delegate;

// configure animation (optional)
@property (nonatomic)         UIColor*             shadowColor;         // default is [UIColor blackColor]
@property (nonatomic, assign) NSTimeInterval       duration;            // default is [DPPrismTransition defaultDuration]
@property (nonatomic, assign) UIViewAnimationCurve timingCurve;         // default is UIViewAnimationCurveEaseInOut
@property (nonatomic, assign) float                perspective;         // default is 700.0
@property (nonatomic, assign) BOOL                 useRenderViewMethod; // default is NO

@property (nonatomic, readonly, getter=isPerformTransitioning) BOOL performTransitioning;
@property (nonatomic, readonly, getter=isManualTransitioning)  BOOL manualTransitioning;

+ (NSTimeInterval)defaultDuration;

- (id)initWithDelegate:(id<DPPrismTransitionDelegate>)delegate
             frontView:(UIView*)frontView
         rightSideView:(UIView*)rightSideView
          leftSideView:(UIView*)leftSideView
                 sides:(NSUInteger)sides
                  type:(DPPrismTransitionType)type
            completion:(DPTransitionCompletionBlock)completion;

- (void)performTransition;

- (void)beginTransitioning;
- (void)setTransitioningProgress:(CGFloat)transitioningProgress; // -1.0 <-> 1.0
- (void)endTransitioning;

@end


@protocol DPPrismTransitionDelegate <NSObject>
@optional
- (void)prismTransitionDidStartTransition:(DPPrismTransition*)prismTransition;
- (void)prismTransitionDidStopTransition:(DPPrismTransition*)prismTransition;
@end
