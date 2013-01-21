//
//  DPPrismViewController+debug_hitTest.m
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2013/01/11.
//  Copyright (c) 2013年 dnpp.org. All rights reserved.
//

#import "DPPrismViewController+debug_hitTest.h"

#if DP_SHOW_DEBUG_UI

#import "DPPrismViewControllerUtils.h"
#import <objc/runtime.h>

#import "DPPrismTransition.h"

#import "DPStoryboardidentifiers.h"
#import "DPRandomNumberHelper.h"

static void swizzle(Class klass, SEL original, SEL alternative)
{
    Method orgMethod = class_getInstanceMethod(klass, original);
    Method altMethod = class_getInstanceMethod(klass, alternative);
    
    if (class_addMethod(klass, original, method_getImplementation(altMethod), method_getTypeEncoding(altMethod))) {
        class_replaceMethod(klass, alternative, method_getImplementation(orgMethod), method_getTypeEncoding(orgMethod));
    }
    else {
        method_exchangeImplementations(orgMethod, altMethod);
    }
}

static NSArray* _requiredActionButtons; // UIButtons
static NSArray* _utilActionButtons;     // UIButtons
static NSArray* _mustFailActionButtons; // UIButtons

@implementation DPPrismViewController (debug_hitTest)

#pragma mark - Hook

+ (void)initialize
{
    static BOOL installed = NO;
    if (installed)
        return;
    
    installed = YES;
    
    swizzle([self class], @selector(viewDidLoad), @selector(debug_viewDidLoad));
}

- (void)debug_viewDidLoad
{
    [self debug_viewDidLoad];
    
    { // for Debug
        __weak UIView* w_view = self.view;
        UIButton* (^addDebugButton)(NSString*, id, SEL, CGRect, UIViewAutoresizing) = ^(NSString* title,id target , SEL action, CGRect frame, UIViewAutoresizing mask){
            UIButton* button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
            button.frame = frame;
            button.autoresizingMask = mask;
            button.alpha = 0.7;
            [button.titleLabel setFont:[UIFont boldSystemFontOfSize:9]];
            [button setTitle:title forState:UIControlStateNormal];
            [w_view addSubview:button];
            return button;
        };
                
        _requiredActionButtons = @[
            addDebugButton((@"←"),                           self, (@selector(debug_clockwise)),                   (CGRectMake(250, 400,  60, 40)), (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin)),
            addDebugButton((@"→"),                           self, (@selector(debug_counterclockwise)),            (CGRectMake( 10, 400,  60, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin)),
            addDebugButton((@"removeVisibleViewController"), self, (@selector(debug_removeVisibleViewController)), (CGRectMake( 10,  20, 145, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"addRandomViewController"),     self, (@selector(debug_addRandomViewController)),     (CGRectMake(170,  20, 145, 40)), (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"setRandomViewControllers"),    self, (@selector(debug_setRandomViewControllers)),    (CGRectMake( 10,  70, 145, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"resetViewControllers"),        self, (@selector(debug_resetViewControllers)),        (CGRectMake(170,  70, 145, 40)), (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleWidth)),
        ];
        
        [self.view addSubview:(^{
            UISlider* slider = [[UISlider alloc] initWithFrame:CGRectMake(80, 410, 160, 23)];
            slider.alpha = 0.7;
            slider.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
            slider.minimumValue = -1.0;
            slider.maximumValue = +1.0;
            slider.value = 0.0;
            slider.continuous = NO;
            [slider addTarget:self action:@selector(debug_sliderTouchDown:)    forControlEvents:UIControlEventTouchDown];
            [slider addTarget:self action:@selector(debug_sliderValueChanged:) forControlEvents:UIControlEventTouchDragInside];
            [slider addTarget:self action:@selector(debug_sliderValueChanged:) forControlEvents:UIControlEventTouchDragOutside];
            [slider addTarget:self action:@selector(debug_sliderTouchUp:)      forControlEvents:UIControlEventTouchUpInside];
            [slider addTarget:self action:@selector(debug_sliderTouchUp:)      forControlEvents:UIControlEventTouchUpOutside];
            return slider;
        }())];
        
        _utilActionButtons = @[
            addDebugButton((@"printViewDetail"),            self, (@selector(debug_printViewDetail)),                 (CGRectMake( 10, 120, 145, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"removeRandomViewController"), self, (@selector(debug_removeRandomViewControllerIndex)), (CGRectMake(170, 120, 145, 40)), (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleWidth)),
        ];
        
        _mustFailActionButtons = @[
            addDebugButton((@"addVisibleViewController"),    self, (@selector(debug_addVisibleViewController)),    (CGRectMake( 10, 170, 145, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"removeNewViewControllers"),    self, (@selector(debug_removeNewViewControllers)),    (CGRectMake(170, 170, 145, 40)), (UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleWidth)),
            addDebugButton((@"addRandomIn_viewControllers"), self, (@selector(debug_addRandomIn_viewControllers)), (CGRectMake( 10, 220, 145, 40)), (UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth)),
        ];
        
        for (UIButton* button in _mustFailActionButtons) {
            button.hidden = YES;
        }
        
    }
}

#pragma mark - Button Actions
#pragma mark Require Actions

- (void)debug_clockwise
{
    [self rotateClockwiseWithAnimated:YES];
}

- (void)debug_counterclockwise
{
    [self rotateCounterclockwiseWithAnimated:YES];
}

- (void)debug_removeVisibleViewController
{
    [self removeViewController:self.visibleViewController];
}

- (NSString*)debug_randomStoryboardidentifier
{
    NSArray* array = (@[
                      SampleNavigationControllerStoryboardID,
                      SampleTabBarControllerStoryboardID,
                      SampleTableControllerStoryboardID
                      ]);
    
    return (NSString*)[array objectAtIndex:[DPRandomNumberHelper randomIntegerWithMin:0 max:(array.count - 1)]];;
}

- (void)debug_addRandomViewController
{
    NSString* identifier = [self debug_randomStoryboardidentifier];
    [self addViewController:[self.storyboard instantiateViewControllerWithIdentifier:identifier]];
}

-(void)debug_setRandomViewControllers
{
    NSInteger sides = [DPRandomNumberHelper randomIntegerWithMin:2 max:6];
    
    NSMutableOrderedSet* viewControllers = [NSMutableOrderedSet orderedSet];
    
    for (NSInteger i = 0; i < sides; i++) {
        NSString* identifier = (NSString*)[@[SampleNavigationControllerStoryboardID, SampleTabBarControllerStoryboardID, SampleTableControllerStoryboardID] objectAtIndex:[DPRandomNumberHelper randomIntegerWithMin:0 max:2]];
        [viewControllers addObject:[self.storyboard instantiateViewControllerWithIdentifier:identifier]];
    }
    
    self.viewControllers = viewControllers;
}

-(void)debug_resetViewControllers
{
    self.viewControllers = [NSOrderedSet orderedSetWithArray:@[
                            [self.storyboard instantiateViewControllerWithIdentifier:SampleNavigationControllerStoryboardID],
                            [self.storyboard instantiateViewControllerWithIdentifier:SampleTabBarControllerStoryboardID],
                            [self.storyboard instantiateViewControllerWithIdentifier:SampleTableControllerStoryboardID],
                            [self.storyboard instantiateViewControllerWithIdentifier:SampleTabBarControllerStoryboardID],
                            ]];
}

- (void)debug_sliderTouchDown:(UISlider*)slider
{
//    self.prismTransition = [[DPPrismTransition alloc] initWithTransitionView:self.transitionView
//                                                               sourceView:self.visibleViewController.view
//                                                          destinationView:self.clockwiseViewController.view
//                                                          isClockwiseMove:YES
//                                                                    sides:self.sides
//                                                                 duration:[DPPrismTransition defaultDuration]
//                                                              timingCurve:UIViewAnimationCurveEaseInOut
//                                                               completion:^(BOOL finished){
//                                                                   if (finished) {
////                                                                       _visibleViewController = self.clockwiseViewController;
//                                                                   }
//                                                               }];
//    [self.prismTransition beginTransitioning];
}

- (void)debug_sliderValueChanged:(UISlider*)slider
{
//    [self.prismTransition setTransitioningProgress:slider.value];
}

- (void)debug_sliderTouchUp:(UISlider*)slider
{
//    [self.prismTransition endTransitioning];
//    slider.value = 0.0;
}

#pragma mark - Util Actions

- (void)debug_printViewDetail
{
    NSString* detail = [NSString stringWithFormat:@"\n%@", [self.view performSelector:@selector(recursiveDescription)]];
    ShowConsole(@"%@", detail);
}

- (void)debug_removeRandomViewControllerIndex
{
    if (self.viewControllers.count == 0)
        return;
    
    NSInteger index = [DPRandomNumberHelper randomIntegerWithMin:0 max:(self.viewControllers.count - 1)];
    [self removeViewControllerAtIndex:index];
}

#pragma mark - Must fail Actions

- (void)debug_addVisibleViewController
{
    [self addViewController:self.visibleViewController];
}


- (void)debug_removeNewViewControllers
{
    [self removeViewController:[[UIViewController alloc] init]];
}

- (void)debug_addRandomIn_viewControllers
{
    if (self.viewControllers.count == 0)
        return;
    
    NSInteger index = [DPRandomNumberHelper randomIntegerWithMin:0 max:(self.viewControllers.count - 1)];
    UIViewController* viewController = [self.viewControllers objectAtIndex:index];
    [self addViewController:viewController];
}

@end

#endif /* DP_SHOW_DEBUG_UI */
