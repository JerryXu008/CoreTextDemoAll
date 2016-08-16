//
//  PhotoScrollView.h
//  在保定
//
//  Created by Hepburn Alex on 13-12-24.
//  Copyright (c) 2013年 iHope. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PhotoScrollViewDelegate <NSObject>

-(void)refreshCurPage:(NSNumber *) pageIndex;
-(void)showCurPageText:(NSString *)txt  mainTxt:(NSString *)maintxt;
@end


@interface PhotoScrollView : UIView<UIScrollViewDelegate> {
    UIScrollView *mScrollView;
    NSMutableArray *mArray;
    int miPage;
    UIPageControl *mPageCtrl;
}

@property (nonatomic, assign) id<PhotoScrollViewDelegate> delegate;
@property (nonatomic, assign) SEL OnSingleClick;
@property (nonatomic, strong) NSMutableArray *mArray;
@property (nonatomic, retain) NSMutableArray *mThumbArray;
@property (nonatomic, retain) NSMutableArray *mTextArray;
@property (nonatomic, retain) NSMutableArray *mMainTextArray;
@property (nonatomic, assign) int miPage;
@property (nonatomic,strong) UIImage* bgImage;

@end
