//
//  NetProgressImageView.m
//  在保定
//
//  Created by Hepburn Alex on 13-12-25.
//  Copyright (c) 2013年 iHope. All rights reserved.
//

#import "NetProgressImageView.h"

@implementation NetProgressImageView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        self.OnLoadProgress = @selector(DidLoadProgress);
        self.OnLoadFinish = @selector(DidLoadFinish);
        self.OnImageLoad = @selector(DidImageLoad);
        mCoverView = [[NetImageView alloc] initWithFrame:self.bounds];
        mCoverView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        mCoverView.mImageType = TImageType_AutoSize;
        [self addSubview:mCoverView];
      
    }
    return self;
}

- (void)GetImageByStr:(NSString *)imagename :(NSString *)thumbname {
    mCoverView.hidden = NO;
    [mCoverView GetImageByStr:thumbname];
    [super GetImageByStr:imagename];
}

- (void)DidLoadProgress {
    if (!mLoadView) {
        [self StartAnimate];
    }
    mLoadView.progress = (float)miDownSize/(float)miFileSize;
}

- (void)DidImageLoad {
    mCoverView.hidden = YES;
}

- (void)DidLoadFinish {
    [self StopAnimate];
}

- (void)StartAnimate {
    mLoadView = [[MBProgressHUD alloc] initWithView:self];
    mLoadView.mode = MBProgressHUDModeDeterminate;
    [self addSubview:mLoadView];
    [mLoadView show:YES];
}

- (void)StopAnimate {
    [mLoadView hide:YES];
    mLoadView = nil;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
