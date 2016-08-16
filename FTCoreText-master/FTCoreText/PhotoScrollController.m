//
//  PhotoScrollController.m
//  在保定
//
//  Created by Hepburn Alex on 13-12-24.
//  Copyright (c) 2013年 iHope. All rights reserved.
//

#import "PhotoScrollController.h"
#import "NetImageView.h"
@interface PhotoScrollController (){
    UILabel *lblPageIndex;
    UILabel *lblPageCount;
    UILabel *lblSubTitle;
    UILabel *lblTitle;
    UIScrollView *scroll;
    UIView * ContentView;
}

@end

@implementation PhotoScrollController
@synthesize mScrollView;

-(void)showAnimation:(CGPoint)point
{
    UIScrollView *scrollView = (UIScrollView *)[mScrollView viewWithTag:5000];
    
    scrollView.alpha = 0.0;
    CGPoint center=scrollView.center;
    double delayInSeconds = 0.01;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            scrollView .alpha = 0.0;
            scrollView.center=CGPointMake(point.x, point.y);
            scrollView.transform = CGAffineTransformMakeScale(0.00001, 0.00001);
            [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             scrollView .alpha = 1.0;
                             scrollView.center=center;
                             scrollView.transform = CGAffineTransformMakeScale( 1.0,  1.0);
                         }
                         completion:nil];

    });
    
   
}




- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    mScrollView = [[PhotoScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    mScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
  //  mScrollView.backgroundColor = [UIColor blackColor];
   // mScrollView.bgImage=[UIImage imageNamed:@"scrollscanerBG.png"];
    mScrollView.backgroundColor = [UIColor blackColor];
    mScrollView.delegate = self;
    mScrollView.OnSingleClick = @selector(hideTextView:);
    [self.view addSubview:mScrollView];
   
   
    [self InitTextViewUI];
    
    mScrollView.miPage = _page;
    mScrollView.mThumbArray = _mThumbArray;
    mScrollView.mArray = _mPhotoArray;
    mScrollView.mTextArray=_mTextArray;
    mScrollView.mMainTextArray=_mMainTextArray;
}
-(void)InitTextViewUI
{
     ContentView=[UIView new];
    ContentView.frame=CGRectMake(0, self.view.frame.size.height-200, self.view.frame.size.width, 200);
    ContentView.backgroundColor=[UIColor blackColor];
    ContentView.alpha=0.8;
    [self.view addSubview:ContentView];
    
    lblTitle=[UILabel new];
    lblTitle.frame=CGRectMake(10, 10, self.view.frame.size.width-55, 20);
    lblTitle.textColor=[UIColor whiteColor];
    [ContentView addSubview:lblTitle];
    lblTitle.text=@"";
    lblTitle.backgroundColor=[UIColor clearColor];
   // lblTitle.backgroundColor=[UIColor redColor];
    
    lblPageIndex=[UILabel new];
    lblPageIndex.text=@"1";
    lblPageIndex.frame=CGRectMake(self.view.frame.size.width-55, 15, 20, 15);
    lblPageIndex.textColor=[UIColor whiteColor];
    lblPageIndex.textAlignment=NSTextAlignmentRight;
    lblPageIndex.backgroundColor=[UIColor clearColor];
    [ContentView addSubview:lblPageIndex];
    
    UILabel *lblline=[UILabel new];
    lblline.backgroundColor=[UIColor clearColor];
    lblline.text=@"/";
    lblline.textColor=[UIColor whiteColor];
    lblline.frame=CGRectMake(lblPageIndex.frame.origin.x+lblPageIndex.frame.size.width+1, 20, 5, 10);
    lblline.font=[UIFont systemFontOfSize:12];
    [ContentView addSubview:lblline];
   
    NSUInteger pageCount= _mPhotoArray.count;
    lblPageCount=[UILabel new];
    lblPageCount.backgroundColor=[UIColor clearColor];
    lblPageCount.text=[NSString stringWithFormat:@"%ld",pageCount ];
    lblPageCount.textColor=[UIColor whiteColor];
    lblPageCount.frame=CGRectMake(lblline.frame.origin.x+lblline.frame.size.width+1, 18, 20, 15);
    lblPageCount.font=[UIFont systemFontOfSize:12];
    lblPageCount.textAlignment=NSTextAlignmentLeft;
    [ContentView addSubview:lblPageCount];
    NSString *text=@"";
    CGSize calcSize = [text sizeWithFont:[UIFont systemFontOfSize:13] constrainedToSize:CGSizeMake(300-10, 10000) lineBreakMode:NSLineBreakByWordWrapping];
    lblSubTitle=[UILabel new];
    lblSubTitle.backgroundColor=[UIColor clearColor];
    lblSubTitle.textColor=[UIColor whiteColor];
    lblSubTitle.font=[UIFont systemFontOfSize:14];
 
    lblSubTitle.frame=CGRectMake(0, 0, self.view.frame.size.width-20, 0);
    lblSubTitle.lineBreakMode = UILineBreakModeWordWrap;
    lblSubTitle.numberOfLines = 0;
    lblSubTitle.frame=CGRectMake(lblSubTitle.frame.origin.x, lblSubTitle.frame.origin.y, lblSubTitle.frame.size.width, calcSize.height+15);
    lblSubTitle.text=text;
   
    scroll=[UIScrollView new];
    scroll.frame=CGRectMake(10, 40, self.view.frame.size.width-20, 150);
    [ContentView addSubview:scroll];
    [scroll addSubview:lblSubTitle];
    scroll.contentSize=CGSizeMake(scroll.frame.size.width, calcSize.height+15+10);
    

}
-(int )getCurPageIndex
{
    NSString *num=lblPageIndex.text;
    if(num==nil||num.length==0)num=@"1";
    int curindex=[num intValue];
    return curindex-1;
}

-(void)refreshCurPage:(NSNumber *)pageIndex
{
    lblPageIndex.text=[NSString stringWithFormat:@"%d",[pageIndex intValue] ];

}
-(void)showCurPageText:(NSString *)txt mainTxt:(NSString *)maintxt
{
    lblSubTitle.text=txt;
    lblTitle.text=maintxt;
    [self refreshView:txt];
}
-(void)refreshView:(NSString *)text
{
    CGSize calcSize = [text sizeWithFont:[UIFont systemFontOfSize:13] constrainedToSize:CGSizeMake(300-10, 10000) lineBreakMode:NSLineBreakByWordWrapping];
    lblSubTitle.frame=CGRectMake(lblSubTitle.frame.origin.x, lblSubTitle.frame.origin.y, lblSubTitle.frame.size.width, calcSize.height+15);
     lblSubTitle.text=text;
     scroll.contentSize=CGSizeMake(scroll.frame.size.width, calcSize.height+15+10);
    
}
- (void)dealloc {
    self.mThumbArray = nil;
    self.mPhotoArray = nil;
    
}
//隐藏文字
-(BOOL)hideTextView:(UIButton *)sender {
    
    ContentView.hidden=!ContentView.hidden;
    return ContentView.hidden;
}

//返回按钮
- (void)backAction:(UIButton *)sender {
    
    [self dismissModalViewControllerAnimated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
