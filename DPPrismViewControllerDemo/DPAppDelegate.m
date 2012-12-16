//
//  DPAppDelegate.m
//  DPPrismViewControllerDemo
//
//  Created by Yusuke Sugamiya on 2012/12/16.
//  Copyright (c) 2012 dnpp.org. All rights reserved.
//

#import "DPAppDelegate.h"
#import "DPPrismViewController.h"
#import "DPStoryboardidentifiers.h"

@implementation DPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    DPPrismViewController* prismViewController = (DPPrismViewController*)self.window.rootViewController;
    UIStoryboard* storyboard = prismViewController.storyboard;
    prismViewController.viewControllers = [NSOrderedSet orderedSetWithArray:@[
                                           [storyboard instantiateViewControllerWithIdentifier:SampleNavigationControllerStoryboardID],
                                           [storyboard instantiateViewControllerWithIdentifier:SampleTabBarControllerStoryboardID],
                                           [storyboard instantiateViewControllerWithIdentifier:SampleTableControllerStoryboardID],
                                           [storyboard instantiateViewControllerWithIdentifier:SampleTabBarControllerStoryboardID],
                                           ]];
    return YES;
}

@end
