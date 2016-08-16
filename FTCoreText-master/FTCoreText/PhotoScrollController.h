//
//  PhotoScrollController.h
//  在保定
//
//  Created by Hepburn Alex on 13-12-24.
//  Copyright (c) 2013年 iHope. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PhotoScrollView.h"

@interface PhotoScrollController : UIViewController<PhotoScrollViewDelegate> {
    PhotoScrollView* mScrollView;
    UIButton *queDingButton;
}

@property (nonatomic, retain) NSMutableArray *mPhotoArray;
@property (nonatomic, retain) NSMutableArray *mThumbArray;
@property (nonatomic, retain) NSMutableArray *mMainTextArray;
@property (nonatomic, retain) NSMutableArray *mTextArray;
//近来显示第几张
@property (assign, nonatomic) int page;
-(BOOL)hideTextView:(UIButton *)sender;
-(int )getCurPageIndex;

-(void)showAnimation:(CGPoint)point;
@property(strong,nonatomic)PhotoScrollView* mScrollView;
@end
