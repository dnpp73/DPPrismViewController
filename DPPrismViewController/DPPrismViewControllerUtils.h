//
//  DPPrismViewControllerUtils.h
//  DPPrismViewController
//
//  Created by Yusuke Sugamiya on 2013/01/07.
//  Copyright (c) 2013年 dnpp.org. All rights reserved.
//

#ifndef DPPrismViewControllerDemo_DPPrismViewControllerUtils_h
#define DPPrismViewControllerDemo_DPPrismViewControllerUtils_h


#ifdef DEBUG
#define ShowConsole(format, ...) NSLog(@"[%@(%p) %@] "format, NSStringFromClass([self class]), self, NSStringFromSelector(_cmd), ##__VA_ARGS__)
#else
#define ShowConsole(format, ...) ;
#endif


#endif
