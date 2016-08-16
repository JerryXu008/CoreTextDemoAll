//
//  TuJiDetailVC.m
//  TestHebei
//
//  Created by iHope on 14-11-3.
//  Copyright (c) 2014年 Hepburn Alex. All rights reserved.
//

#import "TuJiDetailVC.h"


@interface TuJiDetailVC () {
    UIButton * btnFenXiang;
    UIButton * btnShouCang;
    UIButton * btnXiaZai;
    NSString *imgUrl;
   
}

@end

@implementation TuJiDetailVC


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}
-(BOOL)hideTextView:(UIButton *)sender
{
    BOOL hidden= [super hideTextView:sender];
    btnFenXiang.hidden=hidden;
    btnShouCang.hidden=hidden;
    btnXiaZai.hidden=hidden;
    return hidden;
}





/****************************分享****************************/



- (void)viewDidLoad
{
   
    
        self.page = 0;
        self.mPhotoArray=[NSMutableArray new];
        self.mThumbArray=[NSMutableArray new];
        self.mTextArray=[NSMutableArray new];
        self.mMainTextArray=[NSMutableArray new];
        for(int i=0;i<3;i++)
        {
           
            NSString *imageurl=@"http://ia.hebradio.com/resources/picture/1/2015/02/03/20150203132744675.jpg";
            NSString *imagetxt= @"2月1日，国家机关公车拍卖现场，一男子三场竞拍全部现身，当天他跟坐他旁边的男子两人共用288号号牌，至少拍下10辆公车。";
            NSString *mainText=@"直击公车拍卖现场：神秘的288号";
            [self.mPhotoArray addObject:imageurl];
            [self.mThumbArray addObject:imageurl];
            [self.mMainTextArray addObject:mainText];
            [self.mTextArray addObject:imagetxt];

        }
    [super viewDidLoad];
  
    
    //添加下scrollview的显示动画
    [self showAnimation:self.fromPoint];

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    UIButton *btnClose = [UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame = CGRectMake(20, 30, 50, 50);
    // [btnClose setBackgroundImage:[UIImage imageNamed:@"f_btnback"] forState:UIControlStateNormal];
    [btnClose setImage:[UIImage imageNamed:@"f_btnback"] forState:UIControlStateNormal];

    [ btnClose  setImageEdgeInsets:UIEdgeInsetsMake(17,13,17,13)];
    [btnClose addTarget:self action:@selector(closeWindow) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnClose];
    btnClose.backgroundColor=[UIColor redColor];

  
    
    self.title = @"详情";
    self.view.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    
}
-(void)closeWindow
{
   
//    if(_isFromZhuanTi&&_superRootVC){
//        [self.rootVC.navigationController popToViewController:self.superRootVC animated:NO];
//        
//    }
     [self dismissModalViewControllerAnimated:NO];
}

@end
