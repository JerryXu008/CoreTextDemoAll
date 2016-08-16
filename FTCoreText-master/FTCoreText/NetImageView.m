//
//  NetImageView.m
//  TestAppstoreRss
//
//  Created by hepburn X on 11-10-28.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import "NetImageView.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NetImageView

@synthesize mbLoading, mLocalPath, mImageView, mbActShow, mImageType, mDefaultPath, delegate, OnImageLoad, userinfo, OnLoadProgress, miFileSize, miDownSize, OnLoadFinish, mImageCenter;

+ (NSString *)MD5String:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

+ (NSString *)GetLocalPathOfUrl:(NSString *)path {
    if (!path) {
        return nil;
    }
    NSRange headrange = [path rangeOfString:@"http:" options:NSCaseInsensitiveSearch];
    if (headrange.length == 0) {
        return path;
    }
    NSRange range = [path rangeOfString:@"." options:NSBackwardsSearch];
    NSString *extname = [path substringFromIndex:range.location+range.length];
    if (extname.length >= 4) {
        extname = @"jpg";
    }
    NSString *name = [NetImageView MD5String:path];
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *localpath = [docDir stringByAppendingPathComponent:name];
    localpath = [localpath stringByAppendingFormat:@".%@", extname];
    return localpath;
}

- (UIImage *)getSubImage: (UIImage *)image :(CGRect)rect {
    @autoreleasepool {
          CGImageRef subImageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
          UIImage* smallImage = [UIImage imageWithCGImage:subImageRef];
          CGImageRelease(subImageRef);
          return smallImage  ;
    }
    
   
}

////////////////////////////////////////////////////////////////////////

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.mDefaultImage = [UIImage imageNamed:@"default_logo"];
        
        miDownSize = 0;
        mImageType = TImageType_FullFill;
        mbLoading = NO;
        mWebData = [[NSMutableData alloc] init];

        mImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:mImageView];
        
        
        mActView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        mActView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        mActView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        mActView.hidden = YES;
        [self addSubview:mActView];
       
    }
    return self;
}
-(void)setTransFormScaleX:(float)x ScaleY:(float)y
{
  //  mImageView.transform=CGAffineTransformScale(mImageView.transform,x,y);
    self.transform=CGAffineTransformScale(self.transform,x,y);
}
- (void)setMbActShow:(BOOL)bShow {
    mActView.hidden = !bShow;
}

- (BOOL)mbActShow {
    return !mActView.hidden;
}

- (CGRect)GetLocalFrame:(UIImage *)image :(TImageType)type {
    CGRect rect = self.bounds;
    if (type == TImageType_AutoSize) {
        CGSize imageSize = image.size;
        int iWidth = self.frame.size.width;
        int iHeight = self.frame.size.width*imageSize.height/imageSize.width;
        if (iHeight > self.frame.size.height) {
            iHeight = self.frame.size.height;
            iWidth = self.frame.size.height*imageSize.width/imageSize.height;
        }
        int iLeft = (self.frame.size.width-iWidth)/2;
        int iTop = (self.frame.size.height-iHeight)/2;
        rect = CGRectMake(iLeft, iTop, iWidth, iHeight);
    }
    else if (type == TImageType_LeftAlign) {
        CGSize imageSize = image.size;
        int iWidth = self.frame.size.width;
        int iHeight = self.frame.size.width*imageSize.height/imageSize.width;
        if (iHeight > self.frame.size.height) {
            iHeight = self.frame.size.height;
            iWidth = self.frame.size.height*imageSize.width/imageSize.height;
        }
        int iTop = (self.frame.size.height-iHeight)/2;
        rect = CGRectMake(0, iTop, iWidth, iHeight);
    }
    else if (type == TImageType_TopAlign) {
        CGSize imageSize = image.size;
        int iWidth = self.frame.size.width;
        int iHeight = self.frame.size.width*imageSize.height/imageSize.width;
        if (iHeight > self.frame.size.height) {
            iHeight = self.frame.size.height;
            iWidth = self.frame.size.height*imageSize.width/imageSize.height;
        }
        int iLeft = (self.frame.size.width-iWidth)/2;
        rect = CGRectMake(iLeft, 0, iWidth, iHeight);
    }
    return rect;
}

- (CGRect)GetLocalFrame:(UIImage *)image {
    return [self GetLocalFrame:image :mImageType];
}

- (UIImage*)ScaleImageToSize:(UIImage *)image :(CGSize)size {
    UIGraphicsBeginImageContext(size);
    // 绘制改变大小的图片
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    // 从当前context中创建一个改变大小后的图片
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    // 返回新的改变大小后的图片
    return scaledImage;
}

- (UIImage *)GetLocalImage:(UIImage *)image {
    if (mImageType == TImageType_CutFill) {
        int iWidth = image.size.width;
        int iHeight = iWidth*self.frame.size.height/self.frame.size.width;
        if (iHeight>image.size.height) {
            iHeight = image.size.height;
            iWidth = iHeight*self.frame.size.width/self.frame.size.height;
        }
        int iLeft = (image.size.width-iWidth)/2;
        int iTop = (image.size.height-iHeight)/2;
        
        CGRect rect = CGRectMake(iLeft, iTop, iWidth, iHeight);
        image = [self getSubImage:image :rect];
        if (iWidth>self.frame.size.width*2) {
            iWidth = self.frame.size.width*2;
            iHeight = self.frame.size.height*2;
            image = [self ScaleImageToSize:image :CGSizeMake(iWidth, iHeight)];
        }
    }
    return image;
}

- (BOOL)IsLocalPathExist {
    if (self.mLocalPath && [[NSFileManager defaultManager] fileExistsAtPath:self.mLocalPath]) {
        return YES;
    }
    return NO;
}

- (BOOL)ShowLocalImage {
    if ([self IsLocalPathExist]) {
        @autoreleasepool {
       
          UIImage *image = [UIImage imageWithContentsOfFile:self.mLocalPath];
        
        if (image) {
           
            mImageView.image = [self GetLocalImage:image];
            mImageView.frame = [self GetLocalFrame:image];
           
            if (delegate && OnImageLoad) {
                [delegate performSelector:OnImageLoad withObject:self];
               
            }
            
         }
            return YES;
        }
    }
    if (mDefaultPath) {
        UIImage *image = [UIImage imageNamed:mDefaultPath];
        if (image) {
            mImageView.image = [self GetLocalImage:image];
            mImageView.frame = [self GetLocalFrame:image];
            if (delegate && OnImageLoad) {
                [delegate performSelector:OnImageLoad withObject:self];
            }
            return YES;
        }
    }
    @autoreleasepool {
        mImageView.image = self.mDefaultImage;
    if (!self.mDefaultImage) {
        mImageView.frame = self.bounds;
    }
    else {
        mImageView.frame = [self GetLocalFrame:self.mDefaultImage :TImageType_AutoSize];
    }
 }
    return NO;
}

- (void)ShowLocalImage:(NSString *)imagename {
    self.mLocalPath = imagename;
    [self ShowLocalImage];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (mImageView.image) {
        mImageView.frame = [self GetLocalFrame:mImageView.image];
    }
}

- (void)GetImageByStr:(NSString *)path {
    [self Cancel];
    self.mLocalPath = [NetImageView GetLocalPathOfUrl:path];
    if ((!path || path.length == 0) && mDefaultPath) {
        [self ShowLocalImage];
        return;
    }
    if ([self IsLocalPathExist]) {
        [self ShowLocalImage];
        return;
    }
    [mActView startAnimating];
    mbLoading = YES;
    NSURL *url = [NSURL URLWithString:path];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    mConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    NSLog(@"GetImageByStr:%@", path);
	
	//如果连接已经建好，则初始化data
	if (!mConnection) {
        mbLoading = NO;
		NSLog(@"theConnection is NULL");
	}
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    miFileSize = 0;
    if(httpResponse && [httpResponse respondsToSelector:@selector(allHeaderFields)]){
        NSDictionary *HeaderFields = [httpResponse allHeaderFields];
        miFileSize = [[HeaderFields objectForKey:@"Content-Length"] longLongValue];
        //NSLog(@"iTotalSize:%lld, %@", miFileSize, HeaderFields);
    }
    miDownSize = 0;
    if (mWebData) {
        [mWebData setLength: 0];
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (mWebData) {
        [mWebData appendData:data];
    }
    miDownSize = mWebData.length;
    if (delegate && OnLoadProgress) {
        [delegate performSelector:OnLoadProgress withObject:self];
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
    mConnection = nil;
    mbLoading = NO;
    [mActView stopAnimating];
    if (delegate && OnLoadFinish) {
        [delegate performSelector:OnLoadFinish withObject:self];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
    mConnection = nil;
    mbLoading = NO;
    [mActView stopAnimating];
    if (delegate && OnLoadFinish) {
        [delegate performSelector:OnLoadFinish withObject:self];
    }
    if (!mWebData) {
        return;
    }
    [mWebData writeToFile:self.mLocalPath atomically:YES];
    [mWebData setLength: 0];
    
    [self ShowLocalImage];
}

- (void)Cancel {
    @autoreleasepool {
        
   
    self.mLocalPath = nil;
    if (mConnection) {
        [mConnection cancel];
        mConnection = nil;
    }
    if (mWebData) {
        [mWebData setLength: 0];
    }
    mImageView.image = self.mDefaultImage;
    if (!self.mDefaultImage) {
        mImageView.frame = self.bounds;
    }
    else {
        mImageView.frame = [self GetLocalFrame:self.mDefaultImage :TImageType_AutoSize];
    }
    [mActView stopAnimating];
    }
}

- (void)dealloc {
    self.mLocalPath = nil;
    if (mConnection) {
        [mConnection cancel];
        mConnection = nil;
    }
    if (mWebData) {
        
        mWebData = nil;
    }
    self.mDefaultImage = nil;
    self.mDefaultPath = nil;
   }

- (CGPoint)mImageCenter {
    return mImageView.center;
}

@end
