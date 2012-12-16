//
//  DPRenderViewHelper.h
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2013/01/09.
//  Copyright (c) 2013年 dnpp.org. All rights reserved.
//  参考 : https://github.com/mpospese/MPFoldTransition
//

#import <Foundation/Foundation.h>

@interface DPRenderViewHelper : NSObject

+ (UIImage *)renderImageFromView:(UIView *)view;
+ (UIImage *)renderImageFromView:(UIView *)view withRect:(CGRect)frame;
+ (UIImage *)renderImageFromView:(UIView *)view withRect:(CGRect)frame transparentInsets:(UIEdgeInsets)insets;
+ (UIImage *)renderImageForAntialiasing:(UIImage *)image withInsets:(UIEdgeInsets)insets;
+ (UIImage *)renderImageForAntialiasing:(UIImage *)image;

@end
