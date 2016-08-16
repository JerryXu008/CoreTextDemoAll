//
//  CustomerView.m
//  FenDuanCoreText
//
//  Created by song on 15/2/5.
//  Copyright (c) 2015年 song. All rights reserved.
//

#import "CustomerView.h"
@interface CustomerView()
@property (nonatomic) CTFramesetterRef framesetter;
@property(nonatomic) NSMutableAttributedString *attributedString;
@end

@implementation CustomerView

- (NSAttributedString *)attributedString
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@"第一次接触苹果系的富文本编程是在写Mac平台上的一个输入框的时候，输入框中的文字可以设置各种样式，并可以在文字中间插入图片，好在Mac的AppKit中提供了NSTextView这个支持富文本编辑器控件。此控件背后是通过什么方式来描述富文本的呢？答案是NSAttributedString，很多编程语言都提供了AttributedString的概念。NSAttributedString比NSString多了一个Attribute的概念，一个NSAttributedString的对象包含很多的属性，每一个属性都有其对应的字符区域，在这里是使用NSRange来进行描述的。下面是一个NSTextView显示富文本的例子"];
    _attributedString = string;
    
    NSRange remainingRange = NSMakeRange(0, [string length]);
    [string addAttribute:(id)kCTForegroundColorAttributeName value:(id)[UIColor redColor].CGColor range:remainingRange];
    
    
    
    
    return _attributedString;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Drawing code
    CGRect *coumnRects=[self copyColumnRects];

    _framesetter = CTFramesetterCreateWithAttributedString((CFMutableAttributedStringRef)self.attributedString);
    
   // CGMutablePathRef path = CGPathCreateMutable();
    
//    CGRect *cc=[self copyColumnRects];
//    for(int i=0;i<3;i++)
//    {
//        CGPathAddRect(path, NULL, cc[i]);
//    }
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

       CFMutableArrayRef paths = CFArrayCreateMutable( kCFAllocatorDefault, 0, & kCFTypeArrayCallBacks );
    
        CGRect *cc=[self copyColumnRects];
        for(int i=0;i<3;i++)
        {
            if(i==0){
             [[UIColor greenColor] setFill];
             CGContextFillRect(context, cc[i]);
            
            }
            if(i==1){
                [[UIColor yellowColor] setFill];
                CGContextFillRect(context, cc[i]);

            }
            if(i==2){
                [[UIColor purpleColor] setFill];
                CGContextFillRect(context, cc[i]);
                
            }
            NSLog(@"rect x=%f,y=%f",cc[i].origin.x,cc[i].origin.y);
            CGPathRef path2=CGPathCreateWithRect(cc[i], NULL);
            CFArrayAppendValue(paths, path2);
            CGPathRelease(path2);
        }
 
    CFIndex pathCount=CFArrayGetCount(paths);
    CFIndex charIndex=0;
    
    
    for(CFIndex pathIndex=0;pathIndex<pathCount;pathIndex++){
        CGPathRef path=CFArrayGetValueAtIndex(paths, pathIndex);
    
        
        CTFrameRef frame=CTFramesetterCreateFrame(_framesetter, CFRangeMake(charIndex, 0), path, NULL);
        CTFrameDraw(frame, context);
        CFRange frameRange=CTFrameGetVisibleStringRange(frame);
        
        charIndex+=frameRange.length;
        CFRelease(frame);
     
    }
    
    
    
   // CTFrameRef ctFrame = CTFramesetterCreateFrame(_framesetter ,CFRangeMake(0, 0), path, NULL);
    
    
    
   // CTFrameDraw(ctFrame, context);

   
    //CFRelease(ctFrame);
    CFRelease(paths);
    CFRelease(_framesetter);
   
    free(coumnRects);
}
-(CGRect *)copyColumnRects{
    CGRect bounds=CGRectInset(self.bounds, 20, 20);
    
    int column;
    CGRect *columnRects=(CGRect *)calloc(3, sizeof(*columnRects));
    columnRects[0]=bounds;
    //按照框架的宽度等分列
    CGFloat columnWidth=CGRectGetWidth(bounds)/3;
    for(column=0;column<2;column++){
        CGRectDivide(columnRects[column], &columnRects[column], &columnRects[column+1], columnWidth, CGRectMinXEdge);
    }
    
    
    for(column=0;column<3;column++){
        columnRects[column]=CGRectInset(columnRects[column], 10, 10);
    }
    return columnRects;
}



@end
