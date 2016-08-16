//
//  NetProgressImageView.h
//  在保定
//
//  Created by Hepburn Alex on 13-12-25.
//  Copyright (c) 2013年 iHope. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NetImageView.h"
#import "MBProgressHUD.h"

@interface NetProgressImageView : NetImageView {
    MBProgressHUD *mLoadView;
    NetImageView *mCoverView;
}

- (void)GetImageByStr:(NSString *)imagename :(NSString *)thumbname;

@end
