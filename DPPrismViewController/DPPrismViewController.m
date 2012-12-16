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
            [UIViewController attemptRotationToDeviceOrientation];
        };
        return NO;
    }
    
    BOOL shouldAutorotate = YES;
    if (self.onlyCheckVisibleViewControllerRotation == NO) {
        for (UIViewController* viewController in _viewControllers) { // ToDo : iOS 5 のこと考えてない。とりあえず落ちないようにしただけ
            if ([viewController respondsToSelector:@selector(shouldAutorotate)] && [viewController shouldAutorotate] == NO) {
                shouldAutorotate = NO;
                break;
            }
        }
    }
    else {
        if ([_visibleViewController respondsToSelector:@selector(shouldAutorotate)]) {
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
            ShowConsole(@"_viewControllers の中に UIViewController のサブクラスでないものが含まれている。");
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

- (NSInteger)indexOfVisibleViewController
{
    if ([_viewControllers containsObject:_visibleViewController] == NO) {
        ShowConsole(@"_visibleViewController が _viewControllers の中に無かった。");
        return -1;
    }

    return [_viewControllers indexOfObject:_visibleViewController];
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

- (UIViewController*)clockwiseViewController
{
    NSInteger index = self.indexOfClockwiseViewController;
    if (index < 0 && _viewControllers.count <= index) {
        ShowConsole(@"_viewControllers に対して不正な index だ。");
        return nil;
    }
    
    return [_viewControllers objectAtIndex:index];
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

- (UIViewController*)counterclockwiseViewController
{
    NSInteger index = self.indexOfCounterclockwiseViewController;
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
        [self rotateViewClockwiseWithAnimated:NO];
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

- (void)rotateViewClockwiseWithAnimated:(BOOL)animated
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
    }
    
    // 実行の前準備
    // 説明変数
    UIViewController* frontViewController     = _visibleViewController;
    UIViewController* rightSideViewController = self.clockwiseViewController;
    UIViewController* leftSideViewController  = self.counterclockwiseViewController;
    leftSideViewController.view.frame = rightSideViewController.view.frame = frontViewController.view.frame = _rootView.frame = self.view.bounds;
    
    // 時計周り専用
    DPPrismTransitionType type = DPPrismTransitionTypeClockwise;
    __weak DPPrismViewController* w_self = self;
    void (^completion)(BOOL) = ^(BOOL finished){
        if (finished) {
            if ([w_self.viewControllers containsObject:rightSideViewController]) { // transition 中に viewControllers が変わったときのため…
                _visibleViewController = rightSideViewController;
            }
        }
    };
    
    // 実行
    [self performTransitionWithfrontView:frontViewController.view
                           rightSideView:rightSideViewController.view
                            leftSideView:leftSideViewController.view
                                animated:animated
                                    type:type
                              completion:completion];
}

- (void)rotateViewCounterclockwiseWithAnimated:(BOOL)animated
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
    }
    
    // 実行の前準備
    // 説明変数
    UIViewController* frontViewController     = _visibleViewController;
    UIViewController* rightSideViewController = self.clockwiseViewController;
    UIViewController* leftSideViewController  = self.counterclockwiseViewController;
    leftSideViewController.view.frame = rightSideViewController.view.frame = frontViewController.view.frame = _rootView.frame = self.view.bounds;
    
    // 反時計周り専用
    DPPrismTransitionType type = DPPrismTransitionTypeCounterclockwise;
    __weak DPPrismViewController* w_self = self;
    void (^completion)(BOOL) = ^(BOOL finished){
        if (finished) {
            if ([w_self.viewControllers containsObject:leftSideViewController]) { // transition 中に viewControllers が変わったときのため…
                _visibleViewController = leftSideViewController;
            }
        }
    };
    
    // 実行
    [self performTransitionWithfrontView:frontViewController.view
                           rightSideView:rightSideViewController.view
                            leftSideView:leftSideViewController.view
                                animated:animated
                                    type:type
                              completion:completion];
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
    
    if (animated) {
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
        _prismTransition.duration *= 3;
        #endif
        
        [_prismTransition performTransition];
    }
    //
    else {
        UIView* destinationView = nil;
        
        if (type == DPPrismTransitionTypeClockwise)
            destinationView = rightSideView;
        else if (type == DPPrismTransitionTypeCounterclockwise)
            destinationView = leftSideView;
        
        if (destinationView == nil)
            return;
        
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
