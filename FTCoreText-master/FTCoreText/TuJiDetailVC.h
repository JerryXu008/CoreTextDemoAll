//
//  TuJiDetailVC.h
//  TestHebei
//
//  Created by iHope on 14-11-3.
//  Copyright (c) 2014年 Hepburn Alex. All rights reserved.
//

#import <UIKit/UIKit.h>



#import "PhotoScrollController.h"
@interface TuJiDetailVC : PhotoScrollController {
}
@property(nonatomic) CGPoint fromPoint;
@property (nonatomic,weak) UIViewController *rootVC;
@property (nonatomic,weak) UIViewController *superRootVC;
@property (nonatomic) BOOL isFromZhuanTi;
@end
