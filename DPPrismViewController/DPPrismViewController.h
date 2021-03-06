//
//  DPPrismViewController.h
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2012/12/16.
//  Copyright (c) 2012 dnpp.org. All rights reserved.
//


#if DEMO_MODE
#define DP_SHOW_DEBUG_UI 1 // 0 なら何もしないし 1 ならデバッグ用のヒットテストなどが出来るようになる
#endif /* DEMO_MODE */


#import <UIKit/UIKit.h>


typedef void (^DPPrismViewControllerCompletionBlock)(BOOL);


@interface DPPrismViewController : UIViewController

@property (nonatomic, copy)   NSOrderedSet* viewControllers; // これをセットすると childViewController とか色々よしなにしてくれる感じの setter
@property (nonatomic, assign) NSUInteger    sides;           // デフォルトは [viewControllers count] なんだけどこれを弄ると側面の数が変わる感じ

@property (nonatomic, assign) BOOL onlyCheckVisibleViewControllerRotation;

@property (nonatomic, readonly) UIViewController* visibleViewController;
@property (nonatomic, readonly) NSInteger  indexOfVisibleViewController;

- (void)addViewController:(UIViewController*)viewController;
- (void)addViewControllers:(NSOrderedSet*)viewControllers;

- (void)removeViewControllerAtIndex:(NSUInteger)index;
- (void)removeViewController:(UIViewController*)viewController;
- (void)removeViewControllers:(NSSet*)viewControllers;

@property (nonatomic, readonly) NSInteger indexOfClockwiseViewController;
@property (nonatomic, readonly) NSInteger indexOfCounterclockwiseViewController;
@property (nonatomic, readonly) UIViewController* clockwiseViewController;
@property (nonatomic, readonly) UIViewController* counterclockwiseViewController;
- (UIViewController*)clockwiseViewControllerFromViewController:(UIViewController*)viewController;
- (UIViewController*)counterclockwiseViewControllerFromViewController:(UIViewController*)viewController;

- (void)rotateClockwiseWithAnimated:(BOOL)animated;
- (void)rotateClockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion;

- (void)rotateCounterclockwiseWithAnimated:(BOOL)animated;
- (void)rotateCounterclockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion;

@end


@interface UIViewController (DPPrismViewControllerRotation)

@property (nonatomic, readonly) UIViewController* clockwiseViewController;
@property (nonatomic, readonly) UIViewController* counterclockwiseViewController;

- (void)rotateViewControllerClockwiseWithAnimated:(BOOL)animated;
- (void)rotateViewControllerClockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion;;

- (void)rotateViewControllerCounterclockwiseWithAnimated:(BOOL)animated;
- (void)rotateViewControllerCounterclockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion;;

@end