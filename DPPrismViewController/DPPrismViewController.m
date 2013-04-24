//
//  DPPrismViewController.m
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2012/12/16.
//  Copyright (c) 2012 dnpp.org. All rights reserved.
//

#import "DPPrismViewController.h"
#import "DPPrismViewControllerUtils.h"
#import "DPPrismTransition.h"

@interface DPPrismViewController () <DPPrismTransitionDelegate>
{
    NSMutableOrderedSet*     _viewControllers;
    
    __weak UIViewController* _visibleViewController;
    
    NSUInteger _sides;
    BOOL       _setSidesFlag;
    
    UIView* _rootView;
    
    DPPrismTransition* _prismTransition;
    
    NSMutableArray* _delayRemoveViewControllerBlocks; // id
    id _delaySetViewControllersBlock;
    id _delayRotateScreenBlock;
}
@end

@implementation DPPrismViewController

#pragma mark - initializer

- (void)buildRootView
{
    if (_rootView == nil) {
        _rootView = [[UIView alloc] initWithFrame:CGRectZero];
        _rootView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        _rootView.backgroundColor = [UIColor clearColor];
        if (self.isViewLoaded) {
            _rootView.frame = self.view.bounds;
            [self.view insertSubview:_rootView atIndex:0];
        }
    }
    
    if ([self isViewLoaded]) {
        _rootView.frame = self.view.bounds;
        [self.view insertSubview:_rootView atIndex:0];
    }
}

- (void)showVisibleViewController
{
    if (_visibleViewController == nil || [self isViewLoaded] == NO)
        return;
    
    [self buildRootView];
    _visibleViewController.view.frame = _rootView.bounds;
    [_rootView addSubview:_visibleViewController.view];
}

#pragma mark - UIViewController view life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self showVisibleViewController];
    _delayRemoveViewControllerBlocks = [NSMutableArray array];
}

#pragma mark - rotation

// for iOS 5 (cf : http://d.hatena.ne.jp/oropon/20120926/p1)
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if ([self shouldAutorotate] == NO) {
        return NO;
    }
    
    NSUInteger toInterfaceOrientationMask;
    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            toInterfaceOrientationMask = UIInterfaceOrientationMaskPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            toInterfaceOrientationMask = UIInterfaceOrientationMaskPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            toInterfaceOrientationMask = UIInterfaceOrientationMaskLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            toInterfaceOrientationMask = UIInterfaceOrientationMaskLandscapeRight;
            break;
        default:
            return NO;
    }
    
    return ([self supportedInterfaceOrientations] & toInterfaceOrientationMask);
}

- (BOOL)shouldAutorotate
{
    if (_prismTransition.performTransitioning == YES || _prismTransition.manualTransitioning == YES) {
        ShowConsole(@"transition 中なので終わったらデバイスの向きに従って回転させる。");
        _delayRotateScreenBlock = ^{
            int64_t delayInMilliSeconds = 100;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInMilliSeconds * NSEC_PER_MSEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [UIViewController attemptRotationToDeviceOrientation];
            });
        };
        return NO;
    }
    
    BOOL shouldAutorotate = YES;
    if (self.onlyCheckVisibleViewControllerRotation == NO) {
        // 涙の iOS 5 対応
        if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"5"]) {
            BOOL allViewControllersRespondsToShouldAutorotate = YES;
            for (id vc in _viewControllers) allViewControllersRespondsToShouldAutorotate &= [vc respondsToSelector:@selector(shouldAutorotate)];
            // もし独自に実装されてるならそれを信頼する
            if (allViewControllersRespondsToShouldAutorotate) {
                for (UIViewController* viewController in _viewControllers) {
                    if ([viewController respondsToSelector:@selector(shouldAutorotate)] && [viewController shouldAutorotate] == NO) {
                        shouldAutorotate = NO;
                        break;
                    }
                }
            }
            // iOS 5 ならもう回転させなくていいのではないか…という気持ちもなくもないけど、最悪落ちるってことが無いように…
            else {
                shouldAutorotate = NO;
            }
        }
        // iOS 6 以降なら呼ばれるので直で書いていい
        else {
            for (UIViewController* viewController in _viewControllers) {
                if ([viewController respondsToSelector:@selector(shouldAutorotate)] && [viewController shouldAutorotate] == NO) {
                    shouldAutorotate = NO;
                    break;
                }
            }
        }
    }
    else {
        if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"5"]) {
            // もし独自に実装されてるならそれを信頼する
            if ([_visibleViewController respondsToSelector:@selector(shouldAutorotate)]) {
                shouldAutorotate = [_visibleViewController shouldAutorotate];
            }
            // iOS 5 ならもう回転させなくていいのではないか…という気持ちもなくもないけど、最悪落ちるってことが無いように…
            else {
                shouldAutorotate = NO;
            }
        }
        // iOS 6 以降なら呼ばれるので直で書いていい
        else {
            shouldAutorotate = [_visibleViewController shouldAutorotate];
        }
    }
    return shouldAutorotate;
}

- (NSUInteger)supportedInterfaceOrientations
{
    UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskAll;
    if (self.onlyCheckVisibleViewControllerRotation == NO) {
        for (UIViewController* viewController in _viewControllers) {
            if ([viewController respondsToSelector:@selector(supportedInterfaceOrientations)]) { // ToDo : iOS 5 のこと考えてない。とりあえず落ちないようにしただけ
                mask &= [viewController supportedInterfaceOrientations];
            }
        }
    }
    else {
        if ([_visibleViewController respondsToSelector:@selector(supportedInterfaceOrientations)]) {
            mask = [_visibleViewController supportedInterfaceOrientations];
        }
    }
    return mask;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return [_visibleViewController preferredInterfaceOrientationForPresentation];
}

#pragma mark - Accessor

- (void)setViewControllers:(NSOrderedSet*)viewControllers
{
    // 引数チェック
    for (id object in viewControllers) {
        if ([object isKindOfClass:[UIViewController class]] == NO) {
            ShowConsole(@"viewControllers の中に UIViewController のサブクラスでないものが含まれている。");
            return;
        } else if ([object isKindOfClass:[self class]]) {
            ShowConsole(@"DPPrismViewController の派生を入れてネストするとおかしくなる。");
            return;
        }
    }
    
    if (_prismTransition.performTransitioning == YES || _prismTransition.manualTransitioning == YES) {
        ShowConsole(@"transition 中なので終わったら set する。");
        DPPrismViewController* w_self = self;
        _delaySetViewControllersBlock = ^{
            [w_self setViewControllers:viewControllers];
        };
        return;
    }

    if ([_viewControllers isEqualToOrderedSet:viewControllers] == NO) {
        // 旧 _viewControllers の chiledViewController 辺りの後始末をして
        for (UIViewController* viewController in _viewControllers) {
            if (viewController.parentViewController == self) {
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
            }
        }
        
        // んで、セットして
        _viewControllers = viewControllers.mutableCopy;
        
        // 新 viewControllers を childViewController に放り込んで
        for (UIViewController* viewController in viewControllers) {
            [self addChildViewController:viewController];
        }
        
        // とりあえず先頭の viewController を表示して終わり
        _visibleViewController = [viewControllers objectAtIndex:0];
        [self showVisibleViewController];
    }
}

- (NSOrderedSet*)viewControllers
{
    return _viewControllers.copy;
}

- (void)setSides:(NSUInteger)sides
{
    // 引数チェック
    if (_viewControllers.count < sides) {
        ShowConsole(@"sides が _viewControllers.count よりも小さい。");
        return;
    }
    
    _setSidesFlag = YES;
    _sides = sides;
}

- (NSUInteger)sides
{
    if (_setSidesFlag) {
        return _sides;
    }
    else {
        return _viewControllers.count;
    }
}

- (UIViewController*)visibleViewController
{
    return _visibleViewController;
}

- (NSInteger)indexOfViewController:(UIViewController*)viewController
{
    if ([_viewControllers containsObject:viewController] == NO) {
        ShowConsole(@"指定された viewController が _viewControllers の中に無かった。");
        return -1;
    }
    
    return [_viewControllers indexOfObject:viewController];
}

- (NSInteger)indexOfVisibleViewController
{
    return [self indexOfViewController:_visibleViewController];
}

- (NSInteger)indexOfClockwiseViewController
{
    NSInteger index = self.indexOfVisibleViewController;
    if (index < 0) {
        ShowConsole(@"self.indexOfVisibleViewController がおかしい。");
        return -1;
    }
    
    index++;
    if (index == _viewControllers.count) index = 0;
    return index;
}

- (NSInteger)indexOfCounterclockwiseViewController
{
    NSInteger index = self.indexOfVisibleViewController;
    if (index < 0) {
        ShowConsole(@"self.indexOfVisibleViewController がおかしい。");
        return -1;
    }
    
    index--;
    if (index == -1) index = _viewControllers.count - 1;
    return index;
}

- (UIViewController*)clockwiseViewController
{
    NSInteger index = self.indexOfClockwiseViewController;
    if (index < 0 && _viewControllers.count <= index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return nil;
    }
    
    return [_viewControllers objectAtIndex:index];
}

- (UIViewController*)counterclockwiseViewController
{
    NSInteger index = self.indexOfCounterclockwiseViewController;
    if (index < 0 && _viewControllers.count <= index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return nil;
    }

    return [_viewControllers objectAtIndex:index];
}

- (UIViewController*)clockwiseViewControllerFromViewController:(UIViewController*)viewController
{
    NSInteger index = [self indexOfViewController:viewController];
    if (index < 0) {
        ShowConsole(@"[self indexOfViewController:viewController] がおかしい。引数の viewController が _viewControllers の中に無いのだと思う。");
        return nil;
    }
    
    index++;
    if (index == _viewControllers.count) index = 0;
    
    if (index < 0 && _viewControllers.count <= index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return nil;
    }
    
    return [_viewControllers objectAtIndex:index];
}

- (UIViewController*)counterclockwiseViewControllerFromViewController:(UIViewController*)viewController
{
    NSInteger index = [self indexOfViewController:viewController];
    if (index < 0) {
        ShowConsole(@"[self indexOfViewController:viewController] がおかしい。引数の viewController が _viewControllers の中に無いのだと思う。");
        return nil;
    }
    
    index--;
    if (index == -1) index = _viewControllers.count - 1;

    if (index < 0 && _viewControllers.count <= index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return nil;
    }
    
    return [_viewControllers objectAtIndex:index];
}

#pragma mark - implementation (public)

- (void)addViewController:(UIViewController *)viewController // add 系はここに集約
{
    // 引数チェック
    if (viewController == nil) {
        ShowConsole(@"nil なものは放り込めない。");
        return;
    } else if ([viewController isKindOfClass:[self class]]) {
        ShowConsole(@"DPPrismViewController の派生を入れてネストするとおかしくなる。");
        return;
    }
    
    // お節介というか
    if (_viewControllers.count == 0) {
        self.viewControllers = [NSOrderedSet orderedSetWithObject:viewController];
        return;
    }
    
    // インスタンスの状態チェック
    if ([_viewControllers containsObject:viewController]) {
        ShowConsole(@"既に _viewControllers の中に含まれてる。");
        return;
    }

    // 実行
    [self addChildViewController:viewController];
    [_viewControllers addObject:viewController];
}

- (void)addViewControllers:(NSOrderedSet *)viewControllers
{
    // 引数チェック
    if (viewControllers.count == 0) {
        ShowConsole(@"指定された viewControllers が空だ。");
        return;
    }
    
    // お節介というか
    if (_viewControllers.count == 0) {
        self.viewControllers = viewControllers;
        return;
    }
    
    // 実行
    for (UIViewController* viewController in _viewControllers) {
        [self addViewController:viewController];
    }
}

- (void)removeViewControllerAtIndex:(NSUInteger)index // remove 系はここに集約
{
    // インスタンスの状態チェック
    if (_viewControllers.count == 0) {
        ShowConsole(@"_viewControllers が空だ。");
        return;
    } else if (_viewControllers.count == 1) {
        ShowConsole(@"_viewControllers の中に 1 つしか入ってないこれが最後なので remove すると変なことになる。");
        return;
    } else if (_viewControllers.count - 1 < index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return;
    } else if (_prismTransition.performTransitioning == YES || _prismTransition.manualTransitioning == YES) {
        UIViewController* removeViewController = [_viewControllers objectAtIndex:index];
        if (removeViewController == _visibleViewController ||
            removeViewController == self.clockwiseViewController ||
            removeViewController == self.counterclockwiseViewController) {
            ShowConsole(@"_visibleViewController とその両隣に限っては transition 中に remove すると変になるので、終わってから remove する。");
            DPPrismViewController* w_self = self;
            void (^operation)(void) = ^{
                [w_self removeViewController:removeViewController];
            };
            [_delayRemoveViewControllerBlocks addObject:(id)operation];
            return;
        }
    }
    
    // 前処理
    if ([_viewControllers objectAtIndex:index] == _visibleViewController) {
        [self rotateClockwiseWithAnimated:NO];
    }
    
    // 実行
    UIViewController* viewController = (UIViewController*)[_viewControllers objectAtIndex:index];
    if (viewController.view.superview == _rootView) {
        [viewController.view removeFromSuperview];
    }
    [viewController removeFromParentViewController];
    [_viewControllers removeObjectAtIndex:index];
}

- (void)removeViewController:(UIViewController *)viewController
{
    // インスタンスの状態チェック
    if (_viewControllers.count == 0) {
        ShowConsole(@"_viewControllers が空だ。");
        return;
    } else if (_viewControllers.count == 1) {
        ShowConsole(@"_viewControllers の中に 1 つしか入ってないこれが最後なので remove すると変なことになる。");
        return;
    } else if ([_viewControllers containsObject:viewController] == NO) {
        ShowConsole(@"_viewController が _viewControllers の中に無いし、無いものは remove 出来ない。");
        return;
    }
    
    // 実行
    [self removeViewControllerAtIndex:[_viewControllers indexOfObject:viewController]];
}

- (void)removeViewControllers:(NSSet *)viewControllers
{
    // インスタンスの状態チェック
    if (_viewControllers.count == 0) {
        ShowConsole(@"_viewControllers が空だ。");
        return;
    } else if (viewControllers.count > _viewControllers.count) {
        ShowConsole(@"_viewControllers よりも数が多いものを指定されても困る。");
        return;
    }
    
    // 実行
    for (UIViewController* viewController in viewControllers) {
        [self removeViewController:viewController];
    }
}

- (void)rotateClockwiseWithAnimated:(BOOL)animated
{
    [self rotateClockwiseWithAnimated:animated completion:nil];
}

- (void)rotateClockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion
{
    // インスタンスの状態チェック
    if (_viewControllers.count == 0) {
        ShowConsole(@"_viewControllers が空だ。");
        return;
    } else if (_viewControllers.count == 1) {
        ShowConsole(@"_viewControllers の中に 1 つしか入ってないので回転もクソもない。");
        return;
    } else if (_visibleViewController == nil) {
        ShowConsole(@"_visibleViewController が nil なのでどうしようもない。");
        return;
    } else if (_prismTransition.performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_prismTransition.manualTransitioning == YES) {
        ShowConsole(@"_manualTransitioning が YES で他の transition 最中だ。");
        return;
    }
    
    // 実行の前準備
    UIViewController* frontViewController     = _visibleViewController;
    UIViewController* rightSideViewController = self.clockwiseViewController;
    rightSideViewController.view.frame = frontViewController.view.frame = _rootView.frame = self.view.bounds;
    __weak DPPrismViewController* w_self = self;
    void (^privateCompletion)(BOOL) = ^(BOOL finished){
        if (finished) {
            if ([w_self.viewControllers containsObject:rightSideViewController]) { // transition 中に viewControllers が変わったときのため…
                _visibleViewController = rightSideViewController;
            }
        }
        if (completion) {
            completion(finished);
        }
    };
    
    // 実行
    [self performTransitionWithfrontView:frontViewController.view
                           rightSideView:rightSideViewController.view
                            leftSideView:nil
                                animated:animated
                                    type:DPPrismTransitionTypeClockwise
                              completion:privateCompletion];
}

- (void)rotateCounterclockwiseWithAnimated:(BOOL)animated
{
    [self rotateCounterclockwiseWithAnimated:animated completion:nil];
}

- (void)rotateCounterclockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion
{
    // インスタンスの状態チェック
    if (_viewControllers.count == 0) {
        ShowConsole(@"_viewControllers が空だ。");
        return;
    } else if (_viewControllers.count == 1) {
        ShowConsole(@"_viewControllers の中に 1 つしか入ってないので回転もクソもない。");
        return;
    } else if (_visibleViewController == nil) {
        ShowConsole(@"_visibleViewController が nil なのでどうしようもない。");
        return;
    } else if (_prismTransition.performTransitioning == YES) {
        ShowConsole(@"_performTransitioning が YES で他の transition 最中だ。");
        return;
    } else if (_prismTransition.manualTransitioning == YES) {
        ShowConsole(@"_manualTransitioning が YES で他の transition 最中だ。");
        return;
    }
    
    // 実行の前準備
    UIViewController* frontViewController     = _visibleViewController;
    UIViewController* leftSideViewController  = self.counterclockwiseViewController;
    leftSideViewController.view.frame = frontViewController.view.frame = _rootView.frame = self.view.bounds;
    __weak DPPrismViewController* w_self = self;
    void (^privateCompletion)(BOOL) = ^(BOOL finished){
        if (finished) {
            if ([w_self.viewControllers containsObject:leftSideViewController]) { // transition 中に viewControllers が変わったときのため…
                _visibleViewController = leftSideViewController;
            }
        }
        if (completion) {
            completion(finished);
        }
    };
        
    // 実行
    [self performTransitionWithfrontView:frontViewController.view
                           rightSideView:nil
                            leftSideView:leftSideViewController.view
                                animated:animated
                                    type:DPPrismTransitionTypeCounterclockwise
                              completion:privateCompletion];
}

#pragma mark - implementation (private)

- (void)performTransitionWithfrontView:(UIView*)frontView
                         rightSideView:(UIView*)rightSideView
                          leftSideView:(UIView*)leftSideView
                              animated:(BOOL)animated
                                  type:(DPPrismTransitionType)type
                            completion:(void (^)(BOOL))completion // プライベートメソッドで、全てここに集約されてる
{
    if (!(type == DPPrismTransitionTypeClockwise || type == DPPrismTransitionTypeCounterclockwise)) {
        ShowConsole(@"type が Undefined だと困る。");
        return;
    }
    
    UIView* destinationView = nil;
    UIViewAnimationOptions option;
    if (type == DPPrismTransitionTypeClockwise) {
        destinationView = rightSideView;
        option = UIViewAnimationOptionTransitionFlipFromRight;
    } else if (type == DPPrismTransitionTypeCounterclockwise) {
        destinationView = leftSideView;
        option = UIViewAnimationOptionTransitionFlipFromLeft;
    }
    
    if (animated) {
        if (_viewControllers.count != 2) {
            _prismTransition = [[DPPrismTransition alloc] initWithDelegate:self
                                                                 frontView:frontView
                                                             rightSideView:rightSideView
                                                              leftSideView:leftSideView
                                                                     sides:self.sides
                                                                      type:type
                                                                completion:^(BOOL finished){
                                                                    completion(finished);
                                                                    _prismTransition = nil;
                                                                }];
            
            #ifdef DEMO_MODE
//            _prismTransition.useRenderViewMethod = YES;
            #endif
            
            [_prismTransition performTransition];
        }
        else {
            ShowConsole(@"_viewControllers が 2 つなのでデフォルトのを使う");
            [UIView transitionFromView:frontView
                                toView:destinationView
                              duration:[DPPrismTransition defaultDuration]
                               options:option
                            completion:completion];

        }
    }
    // DPPrismTransition の中でやってることは大体こんな感じなんだけど、うーん。
    else {
        [_rootView addSubview:destinationView];
        [frontView removeFromSuperview];
        completion(YES);
    }
}

#pragma mark - DPPrismTransitionDelegate

- (void)prismTransitionDidStartTransition:(DPPrismTransition *)prismTransition
{
    if (_prismTransition == prismTransition) {
        
    }
}

- (void)prismTransitionDidStopTransition:(DPPrismTransition *)prismTransition
{
    if (_prismTransition == prismTransition) {
        // transition 中に removeViewController 系が発行されてたらここで処理
        if (_delayRemoveViewControllerBlocks.count > 0) {
            for (id operation in _delayRemoveViewControllerBlocks) {
                ((void (^)(void))operation)();
            }
            [_delayRemoveViewControllerBlocks removeAllObjects];
        }
        
        // transition 中に viewControllers に変更があったら終わったタイミングで実行
        if (_delaySetViewControllersBlock) {
            ((void(^)(void))_delaySetViewControllersBlock)();
            _delaySetViewControllersBlock = nil;
        }
        // transition 中にデバイスの方向が変わったら終わったタイミングで回転実行
        if (_delayRotateScreenBlock) {
            ((void(^)(void))_delayRotateScreenBlock)();
            _delayRotateScreenBlock = nil;
        }
    }
}

@end


@implementation UIViewController (DPPrismViewControllerRotation)

- (UIViewController*)clockwiseViewController
{
    if ([self.parentViewController isKindOfClass:[DPPrismViewController class]] == NO) {
        ShowConsole(@"parentViewController が DPPrismViewController ではない。");
        return nil;
    }
    
    return [(DPPrismViewController*)self.parentViewController clockwiseViewControllerFromViewController:self];
}

- (UIViewController*)counterclockwiseViewController
{
    if ([self.parentViewController isKindOfClass:[DPPrismViewController class]] == NO) {
        ShowConsole(@"parentViewController が DPPrismViewController ではない。");
        return nil;
    }
    
    return [(DPPrismViewController*)self.parentViewController counterclockwiseViewControllerFromViewController:self];
}

- (void)rotateViewControllerClockwiseWithAnimated:(BOOL)animated
{
    [self rotateViewControllerClockwiseWithAnimated:animated completion:nil];
}

- (void)rotateViewControllerClockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion
{
    if ([self.parentViewController isKindOfClass:[DPPrismViewController class]] == NO) {
        ShowConsole(@"parentViewController が DPPrismViewController ではない。");
        return;
    } else if ([(DPPrismViewController*)self.parentViewController visibleViewController] != self) {
        ShowConsole(@"visibleViewController ではない。");
        return;
    }
    
    [(DPPrismViewController*)self.parentViewController rotateClockwiseWithAnimated:animated completion:completion];
}

- (void)rotateViewControllerCounterclockwiseWithAnimated:(BOOL)animated
{
    [self rotateViewControllerCounterclockwiseWithAnimated:animated completion:nil];
}

- (void)rotateViewControllerCounterclockwiseWithAnimated:(BOOL)animated completion:(DPPrismViewControllerCompletionBlock)completion
{
    if ([self.parentViewController isKindOfClass:[DPPrismViewController class]] == NO) {
        ShowConsole(@"parentViewController が DPPrismViewController ではない。");
        return;
    } else if ([(DPPrismViewController*)self.parentViewController visibleViewController] != self) {
        ShowConsole(@"visibleViewController ではない。");
        return;
    }
    
    [(DPPrismViewController*)self.parentViewController rotateCounterclockwiseWithAnimated:animated completion:completion];
}

@end
