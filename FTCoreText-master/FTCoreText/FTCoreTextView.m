//
//  FTCoreTextView.m
//  FTCoreText
//
//  Copyright 2011 Fuerte International. All rights reserved.
//

#import "FTCoreTextView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "NetImageView.h"
#import "TuJiDetailVC.h"
#define FTCT_SYSTEM_VERSION_LESS_THAN(v)			([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define DEFAULT_NET_IMAGE_WIDTH 280.0f
#define DEFAULT_NET_IMAGE_HEIGHT 160.0f
#pragma mark - Custom categories headers

@interface NSData (FTCoreTextAdditions)

+ (NSData *)ftct_dataWithBase64EncodedString:(NSString *)string;

@end


#pragma mark - FTCoreText

NSString *const FTCoreTextTagDefault = @"_default";
NSString *const FTCoreTextTagImage = @"_image";
NSString *const FTCoreTextTagBullet = @"_bullet";
NSString *const FTCoreTextTagPage = @"_page";
NSString *const FTCoreTextTagLink = @"_link";

NSString *const FTCoreTextDataURL = @"url"; //回调信息中url
NSString *const FTCoreTextDataName = @"FTCoreTextDataName";//回调信息中标签名
NSString *const FTCoreTextDataFrame = @"FTCoreTextDataFrame";//回调信息中frame
NSString *const FTCoreTextDataAttributes = @"FTCoreTextDataAttributes"; //回调信息中文本属性


typedef NS_ENUM(NSInteger, FTCoreTextTagType) {
	FTCoreTextTagTypeOpen,
	FTCoreTextTagTypeClose,
	FTCoreTextTagTypeSelfClose
};


@interface FTCoreTextNode : NSObject

@property (nonatomic, assign) FTCoreTextNode *supernode; //父亲node
@property (nonatomic) NSArray *subnodes; //孩子node
@property (nonatomic, copy) FTCoreTextStyle *style;
@property (nonatomic) NSRange styleRange;//涉及到的范围
@property (nonatomic) BOOL isClosed; //是否到了闭合标签
@property (nonatomic) NSInteger startLocation; //node起始位置
@property (nonatomic) BOOL isLink;//是连接
@property (nonatomic) BOOL isImage;//是图片
@property (nonatomic) BOOL isBullet;//是自定义图标
@property (nonatomic) NSString *imageName; //图片名字

- (NSString *)descriptionOfTree;
- (NSString *)descriptionToRoot;
- (void)addSubnode:(FTCoreTextNode *)node;
- (void)adjustStylesAndSubstylesRangesByRange:(NSRange)insertedRange;
- (void)insertSubnode:(FTCoreTextNode *)subnode atIndex:(NSUInteger)index;
- (void)insertSubnode:(FTCoreTextNode *)subnode beforeNode:(FTCoreTextNode *)node;
- (FTCoreTextNode *)previousNode;
- (FTCoreTextNode *)nextNode;
- (NSUInteger)nodeIndex;
- (FTCoreTextNode *)subnodeAtIndex:(NSUInteger)index;


@end


@implementation FTCoreTextNode

- (NSArray *)subnodes
{
	if (_subnodes == nil) {
		_subnodes = [NSMutableArray new];
	}
	return _subnodes;
}

- (void)addSubnode:(FTCoreTextNode *)node
{
	[self insertSubnode:node atIndex:[_subnodes count]];
}

- (void)insertSubnode:(FTCoreTextNode *)subnode atIndex:(NSUInteger)index
{
	subnode.supernode = self;
	
	NSMutableArray *subnodes = (NSMutableArray *)self.subnodes;
	if (index <= [_subnodes count]) {
		[subnodes insertObject:subnode atIndex:index];
	}
	else {
		[subnodes addObject:subnode];
	}
}

- (void)insertSubnode:(FTCoreTextNode *)subnode beforeNode:(FTCoreTextNode *)node
{
	NSInteger existingNodeIndex = [_subnodes indexOfObject:node];
	if (existingNodeIndex == NSNotFound) {
		[self addSubnode:subnode];
	}
	else {
		[self insertSubnode:subnode atIndex:existingNodeIndex];
	}
}
//父亲结点数目
- (NSInteger)numberOfParents
{
	NSInteger returnedValue = 0;
	FTCoreTextNode *node = self.supernode;
	while (node) {
		returnedValue++;
		node = node.supernode;
	}
	return returnedValue;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@\t-\t%@ - \t%@", [super description], _style.name, NSStringFromRange(_styleRange)];
}

- (NSString *)descriptionToRoot
{
	NSMutableString *description = [NSMutableString stringWithString:@"\n\n"];
	
	FTCoreTextNode *node = self;
	do {
		[description insertString:[NSString stringWithFormat:@"%@",[self description]] atIndex:0];
		
		for (int i = 0; i < [self numberOfParents]; i++) {
			[description insertString:@"\t" atIndex:0];
		}
		[description insertString:@"\n" atIndex:0];
		node = node.supernode;
		
	} while (node);
	
	return description;
}

- (NSString *)descriptionOfTree
{
	NSMutableString *description = [[NSMutableString alloc] init];
	for (int i = 0; i < [self numberOfParents]; i++) {
		[description insertString:@"\t" atIndex:0];
	}
	[description appendFormat:@"%@\n", [self description]];
	for (FTCoreTextNode *node in _subnodes) {
		[description appendString:[node descriptionOfTree]];
	}
	return description;
}

//递归获取全部子节点
- (NSArray *)_allSubnodes //前跟遍历
{
	NSMutableArray *subnodes = [[NSMutableArray alloc] init];
	for (FTCoreTextNode *node in _subnodes) {
		[subnodes addObject:node];
		if (node.subnodes) [subnodes addObjectsFromArray:[node _allSubnodes]];
	}
	return subnodes;
}

//return an array of nodes starting with the current and recursively adding all its child nodes
//返回自身和他下面得所有子节点
- (NSArray *)allSubnodes
{
	NSMutableArray *returnedArray;
	@autoreleasepool {
		NSArray *allSubnodes = [[self _allSubnodes] copy];
		returnedArray = [[NSMutableArray alloc] initWithObjects:self, nil];
		[returnedArray addObjectsFromArray:allSubnodes];
	}
	return returnedArray;
}
//调整结点的范围，移动
- (void)adjustStylesAndSubstylesRangesByRange:(NSRange)insertedRange
{
	NSRange range = self.styleRange;
	if (range.length + range.location > insertedRange.location) {
		range.location += insertedRange.length;
	}
	self.styleRange = range;
	
	for (FTCoreTextNode *node in _subnodes) {
		[node adjustStylesAndSubstylesRangesByRange:insertedRange];
	}
}
//同层次结点中的索引
- (NSUInteger)nodeIndex
{
	return [_supernode.subnodes indexOfObject:self];
}
//返回某个索引的子节点
- (FTCoreTextNode *)subnodeAtIndex:(NSUInteger)index
{
	if (index < [_subnodes count]) {
		return [_subnodes objectAtIndex:index];
	}
	return nil;
}
//本节点之前的结点
- (FTCoreTextNode *)previousNode
{
	NSUInteger index = [self nodeIndex];
	if (index != NSNotFound) {
		return [_supernode subnodeAtIndex:index - 1];
	}
	return nil;
}
//本节点下一个结点
- (FTCoreTextNode *)nextNode
{
	NSUInteger index = [self nodeIndex];
	if (index != NSNotFound) {
		return [_supernode subnodeAtIndex:index + 1];
	}
	return nil;
}

@end

















@interface FTCoreTextView ()

@property (nonatomic) CTFramesetterRef framesetter;
@property (nonatomic) FTCoreTextNode *rootNode;
@property (nonatomic, readwrite) NSAttributedString	*attributedString;
@property (nonatomic) NSDictionary *touchedData;
@property (nonatomic) NSArray *selectionsViews;

CTFontRef CTFontCreateFromUIFont(UIFont *font);
UITextAlignment UITextAlignmentFromCoreTextAlignment(FTCoreTextAlignement alignment);
NSInteger rangeSort(NSString *range1, NSString *range2, void *context);

- (void)updateFramesetterIfNeeded;
- (void)processText;
- (void)drawImages;
- (void)doInit;
- (void)didMakeChanges;
- (NSString *)defaultTagNameForKey:(NSString *)tagKey;
- (NSMutableArray *)divideTextInPages:(NSString *)string;
- (NSString*)getNodeIndexYCoordinate:(CGFloat)coord;

@property(nonatomic,strong) NSMutableArray *clipViews;//图片集合
@property(nonatomic,strong) NSArray *clipViewsFrames;
@property (nonatomic) CGFloat scaleX; // default is 2.0f
@property (nonatomic) CGFloat scaleY; // default is 2.0f

@end


@implementation FTCoreTextView

#pragma mark - Tools methods

- (NSString*)getNodeIndexThatContainLocationFormNSRange:(NSRange)range
{
    FTCoreTextNode *node = [self getNodeThatContainLocationFormNSRange:range];
    return [self getIndexingForNode:node];
}

- (FTCoreTextNode*)getNodeThatContainLocationFormNSRange:(NSRange)range
{
    FTCoreTextNode *currentNode = self.rootNode;
    int i = 0;
    NSInteger count = [currentNode.subnodes count];
    while (currentNode.subnodes && count>i)
    {
        FTCoreTextNode *node = [currentNode.subnodes objectAtIndex:i];
        if (range.length==0 && node.styleRange.location==range.location && node.styleRange.length==0)
        {
            currentNode=node;
            count = [currentNode.subnodes count];
            i=0;
            continue;
        }
        if (node.styleRange.location<=range.location && (node.styleRange.location + node.styleRange.length)>range.location)
        {
            currentNode=node;
            count = [currentNode.subnodes count];
            i=0;
            continue;
        }
        i++;
    }
    return currentNode;
}

- (NSInteger)getCorrectLocationFromNSRange:(NSRange)range
{
    FTCoreTextNode *currentNode = self.rootNode;
    int i = 0;
    NSInteger count = [currentNode.subnodes count];
    while (currentNode.subnodes && count>i)
    {
        FTCoreTextNode *node = [currentNode.subnodes objectAtIndex:i];
        if (node.styleRange.location<=range.location && (node.styleRange.location + node.styleRange.length)>range.location)
        {
            currentNode=node;
            count = [currentNode.subnodes count];
            i=0;
            continue;
        }
        i++;
    }
    return range.location - currentNode.styleRange.location;
}


- (NSString *)getIndexingForNode:(FTCoreTextNode*)node
{
    NSString *string = [NSString string];
    FTCoreTextNode *currentNode = node;
    do {
        if (currentNode==self.rootNode)
        {
            string = [NSString stringWithFormat:@"%lu%@", (unsigned long)currentNode.nodeIndex,string];
        }
        else
        {
            string = [NSString stringWithFormat:@"/%lu%@", (unsigned long)currentNode.nodeIndex,string];
        }
        currentNode=currentNode.supernode;
    } while (currentNode);
    return string;
}

- (NSString*)getNodeIndexYCoordinate:(CGFloat)coord;
{
    CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    NSInteger lineCount = [lines count];
    CGPoint origins[lineCount];
    if (lineCount != 0)
    {
        CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
        
        for (int i = 0; i < lineCount; i++)
        {
            CGPoint baselineOrigin = origins[i];
            //the view is inverted, the y origin of the baseline is upside down
            baselineOrigin.y = CGRectGetHeight(self.frame) - baselineOrigin.y;
            
            CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
            CGFloat ascent, descent;
            CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            
            CGRect lineFrame = CGRectMake(baselineOrigin.x, baselineOrigin.y - ascent, lineWidth, ascent + descent);
            BOOL isContained = (coord>=lineFrame.origin.y)&&(coord<(lineFrame.origin.y+lineFrame.size.height));
            if (isContained)
            {
                CFRange lineRange= CTLineGetStringRange(line);
                NSRange lineNSRange = {lineRange.location,lineRange.length};
                FTCoreTextNode *myNode = [self getNodeThatContainLocationFormNSRange:lineNSRange];
                CFRelease(ctframe);
                return [self getIndexingForNode:myNode];
            }
        }
    }
    CFRelease(ctframe);
    return nil;
}

- (NSRange)getLineRangeForYCoordinate:(CGFloat)coord;
{
    CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    NSInteger lineCount = [lines count];
    CGPoint origins[lineCount];
    if (lineCount != 0)
    {
        CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
        
        for (int i = 0; i < lineCount; i++)
        {
            CGPoint baselineOrigin = origins[i];
            //the view is inverted, the y origin of the baseline is upside down
            baselineOrigin.y = CGRectGetHeight(self.frame) - baselineOrigin.y;
            
            CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
            CGFloat ascent, descent;
            CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            
            CGRect lineFrame = CGRectMake(baselineOrigin.x, baselineOrigin.y - ascent, lineWidth, ascent + descent);
            BOOL isContained = (coord>=lineFrame.origin.y)&&(coord<=lineFrame.origin.y+lineFrame.size.height);
            if (isContained)
            {
                CFRange lineRange= CTLineGetStringRange(line);
                NSRange lineNSRange = {lineRange.location,lineRange.length};
                return lineNSRange;
            }
        }
    }
    CFRelease(ctframe);
    NSRange faultRange;
    faultRange.location =NSNotFound;
    faultRange.length = 0;
    return faultRange;
}


NSInteger rangeSort(NSString *range1, NSString *range2, void *context)
{
    NSRange r1 = NSRangeFromString(range1);
	NSRange r2 = NSRangeFromString(range2);
	
    if (r1.location < r2.location)
        return NSOrderedAscending;
    else if (r1.location > r2.location)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

CTFontRef CTFontCreateFromUIFont(UIFont *font)
{
    CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName,
                                            font.pointSize,
                                            NULL);
    return ctFont;
}

#pragma mark - FTCoreTextView business
#pragma mark -

- (void)changeDefaultTag:(NSString *)coreTextTag toTag:(NSString *)newDefaultTag
{
	if ([_defaultsTags objectForKey:coreTextTag] == nil) {
		[NSException raise:NSInvalidArgumentException format:@"%@ is not a default tag of FTCoreTextView. Use the constant FTCoreTextTag constants.", coreTextTag];
	}
	else {
		[_defaultsTags setObject:newDefaultTag forKey:coreTextTag];
	}
}

- (NSString *)defaultTagNameForKey:(NSString *)tagKey
{
	return [_defaultsTags objectForKey:tagKey];
}

- (void)didMakeChanges
{
	_coreTextViewFlags.updatedAttrString = NO;
	_coreTextViewFlags.updatedFramesetter = NO;
}

#pragma mark - UI related
//触摸的时候根据手指的坐标返回数据
- (NSDictionary *)dataForPoint:(CGPoint)point
{
	return [self dataForPoint:point activeRects:nil];
}

- (NSDictionary *)dataForPoint:(CGPoint)point activeRects:(NSArray **)activeRects
{
	NSMutableDictionary *returnedDict = [NSMutableDictionary dictionary];
	
	CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
	
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
	
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    NSInteger lineCount = [lines count];
    CGPoint origins[lineCount];
    
    if (lineCount != 0) {
		
		CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
		
		for (int i = 0; i < lineCount; i++) {
			CGPoint baselineOrigin = origins[i];
			//the view is inverted, the y origin of the baseline is upside down
			baselineOrigin.y = CGRectGetHeight(self.frame) - baselineOrigin.y;
			
			CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
			CGFloat ascent, descent;
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
			
			CGRect lineFrame = CGRectMake(baselineOrigin.x, baselineOrigin.y - ascent, lineWidth, ascent + descent);
			
			if (CGRectContainsPoint(lineFrame, point)) {
				//we look if the position of the touch is correct on the line
				//得到这一行手指点击的字符的索引
				CFIndex index = CTLineGetStringIndexForPosition(line, point);
                
				NSArray *urlsKeys = [_URLs allKeys];
				
				for (NSString *key in urlsKeys) {
					NSRange range = NSRangeFromString(key);
					if (index >= range.location && index < range.location + range.length) {
						NSURL *url = [_URLs objectForKey:key];
						if (url) [returnedDict setObject:url forKey:FTCoreTextDataURL];
						
						if (activeRects && _highlightTouch) {
							//we looks for the rects enclosing the entire active section
							NSInteger startIndex = range.location;
							NSInteger endIndex = range.location + range.length;
							
							//we look for the line that contains the start index
							NSInteger startLineIndex = i;
							for (int iLine = i; iLine >= 0; iLine--) {
								CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:iLine];
								CFRange range = CTLineGetStringRange(line);
								if (range.location <= startIndex && range.location + range.length >= startIndex) {
									startLineIndex = iLine;
									break;
								}
							}
							//we look for the line that contains the end index
							NSInteger endLineIndex = startLineIndex;
							for (int iLine = i; iLine < lineCount; iLine++) {
								CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:iLine];
								CFRange range = CTLineGetStringRange(line);
								if (range.location <= endIndex && range.location + range.length >= endIndex) {
									endLineIndex = iLine;
									break;
								}
							}
							//we get enclosing rects  获得全部的rect
							NSMutableArray *rectsStrings = [NSMutableArray new];
							for (NSInteger iLine = startLineIndex; iLine <= endLineIndex; iLine++) {
								CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:iLine];
								CGFloat ascent, descent;
								CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
								
								CGPoint baselineOrigin = origins[iLine];
								//the view is inverted, the y origin of the baseline is upside down
								baselineOrigin.y = CGRectGetHeight(self.frame) - baselineOrigin.y;
								
								CGRect lineFrame = CGRectMake(baselineOrigin.x, baselineOrigin.y - ascent, lineWidth, ascent + descent);
								CGRect actualRect = CGRectZero;
								actualRect.size.height = lineFrame.size.height;
								actualRect.origin.y = lineFrame.origin.y;
								
								CFRange range = CTLineGetStringRange(line);
								if (range.location >= startIndex) {
									//the beginning of the line is included 这一行开头是连接
									actualRect.origin.x = lineFrame.origin.x;
								} else {
									actualRect.origin.x = CTLineGetOffsetForStringIndex(line, startIndex, NULL);
								}
								NSInteger lineRangEnd = range.length + range.location;
								if (lineRangEnd <= endIndex) {
									//the end of the line is included  这一行到结尾都是链接
									actualRect.size.width = CGRectGetMaxX(lineFrame) - CGRectGetMinX(actualRect);
								} else {
									CGFloat position = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
									actualRect.size.width = position - CGRectGetMinX(actualRect);
								}
								actualRect = CGRectInset(actualRect, -1, 0);//宽向外宽展2像素
								[rectsStrings addObject:NSStringFromCGRect(actualRect)];
							}
							
							*activeRects = rectsStrings;
						}
						break;
					}
				}//	for (NSString *key in urlsKeys)
                
                //frame
                CFArrayRef runs = CTLineGetGlyphRuns(line);//获取line中包含所有run的数组,我的理解是返回几种属性类型，通过applyStyle方法添加进去的
                
                int iii=CFArrayGetCount(runs);
                
                for(CFIndex j = 0; j < CFArrayGetCount(runs); j++) {
                    CTRunRef run = CFArrayGetValueAtIndex(runs, j);
                    NSDictionary *attributes = (__bridge NSDictionary*)CTRunGetAttributes(run);
                    
                    NSString *name = [attributes objectForKey:FTCoreTextDataName];
                    if (![name isEqualToString:FTCoreTextTagLink]) continue;
                    
                    [returnedDict setObject:name forKey:FTCoreTextDataName];
                    [returnedDict setObject:attributes forKey:FTCoreTextDataAttributes];
                    
                    CGRect runBounds;
                    runBounds.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL); //8
                    runBounds.size.height = ascent + descent;
                    
                    CGFloat xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL); //9
                    runBounds.origin.x = baselineOrigin.x + self.frame.origin.x + xOffset;
                    runBounds.origin.y = baselineOrigin.y + lineFrame.size.height - ascent;
                    
                    [returnedDict setObject:NSStringFromCGRect(runBounds) forKey:FTCoreTextDataFrame];
                }
            }//if (CGRectContainsPoint(lineFrame, point)) 
            if (returnedDict.count > 0){
                break;
            }
		} //for (int i = 0; i < lineCount; i++)
	}

	if (ctframe) {
		CFRelease(ctframe);
	}
	return returnedDict;
}


- (void)updateFramesetterIfNeeded
{
    if (!_coreTextViewFlags.updatedAttrString) {
		if (_framesetter != NULL) CFRelease(_framesetter);
		_framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.attributedString);
		_coreTextViewFlags.updatedAttrString = YES;
		_coreTextViewFlags.updatedFramesetter = YES;
    }
}

/*!
 * @abstract get the supposed size of the drawn text
 *
 */

- (CGSize)suggestedSizeConstrainedToSize:(CGSize)size
{
	CGSize suggestedSize;
	[self updateFramesetterIfNeeded];
	if (_framesetter == NULL) {
		return CGSizeZero;
	}
   // size=CGSizeMake(320, 100);
	suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, size, NULL);
	suggestedSize = CGSizeMake(ceilf(suggestedSize.width), ceilf(suggestedSize.height));
    return suggestedSize;
}

/*!
 * @abstract handy method to fit to the suggested height in one call
 *
 */

- (void)fitToSuggestedHeight
{
	CGSize suggestedSize = [self suggestedSizeConstrainedToSize:CGSizeMake(CGRectGetWidth(self.frame), MAXFLOAT)];
	CGRect viewFrame = self.frame;
	viewFrame.size.height = suggestedSize.height;
	self.frame = viewFrame;
    //self.frame=CGRectMake(0, 0, 320, 400);
}

#pragma mark - Text processing

/*!
 * @abstract remove the tags from the text and create a tree representation of the text
  移除标签，并且创造一个文本的层次树
 *
 */

- (void)processText
{
    
    
   
    if (!_text || [_text length] == 0) return;
	
	[_URLs removeAllObjects];
    [_images removeAllObjects];
    
    for (id clipView in self.clipViews) {
        [clipView removeFromSuperview];
    }
    [_clipViews removeAllObjects];
    
    
	FTCoreTextNode *rootNode = [FTCoreTextNode new];
	rootNode.style = [_styles objectForKey:[self defaultTagNameForKey:FTCoreTextTagDefault]];
	
	FTCoreTextNode *currentSupernode = rootNode;
	
	NSMutableString *processedString = [NSMutableString stringWithString:_text];
	
	BOOL finished = NO;
	NSRange remainingRange = NSMakeRange(0, [processedString length]);
	
	NSString *regEx = @"<(/){0,1}.*?( /){0,1}>";
	
	while (!finished) {
		//标签的范围
		NSRange tagRange = [processedString rangeOfString:regEx options:NSRegularExpressionSearch range:remainingRange];
		
		if (tagRange.location == NSNotFound) {
			if (currentSupernode != rootNode && !currentSupernode.isClosed) {
				if (_verbose) NSLog(@"FTCoreTextView :%@ - Couldn't parse text because tag '%@' at position %ld is not closed - aborting rendering", self, currentSupernode.style.name, (long)currentSupernode.startLocation);
				return;
			}
			finished = YES;
            continue;
		}
        
        NSString *fullTag = [processedString substringWithRange:tagRange];
        FTCoreTextTagType tagType;
        
        if ([fullTag rangeOfString:@"</"].location == 0) {
            tagType = FTCoreTextTagTypeClose;
        }
        else if ([fullTag rangeOfString:@"/>"].location == NSNotFound && [fullTag rangeOfString:@" />"].location == NSNotFound) {
            tagType = FTCoreTextTagTypeOpen;
        }
        else {
            tagType = FTCoreTextTagTypeSelfClose;
        }
        
		NSArray *tagsComponents = [fullTag componentsSeparatedByString:@" "];
		NSString *tagName = (tagsComponents.count > 0) ? [tagsComponents objectAtIndex:0] : fullTag;
        
        tagName = [tagName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"< />"]];
		
        FTCoreTextStyle *style = [_styles objectForKey:tagName];
        
        if (style == nil) {
            style = [_styles objectForKey:[self defaultTagNameForKey:FTCoreTextTagDefault]];
            if (_verbose) NSLog(@"FTCoreTextView :%@ - Couldn't find style for tag '%@'", self, tagName);
        }
		
        switch (tagType) {
            case FTCoreTextTagTypeOpen: //开放标签
            {
                if (currentSupernode.isLink || currentSupernode.isImage) {
                    NSString *predefinedTag = nil;
                    if (currentSupernode.isLink) predefinedTag = [self defaultTagNameForKey:FTCoreTextTagLink];
                    else if (currentSupernode.isImage) predefinedTag = [self defaultTagNameForKey:FTCoreTextTagImage];
                    if (_verbose) NSLog(@"FTCoreTextView :%@ - You can't open a new tag inside a '%@' tag - aborting rendering", self, predefinedTag);
                    return;
                }
                
                FTCoreTextNode *newNode = [FTCoreTextNode new];
                newNode.style = style;
                newNode.startLocation = tagRange.location;
                if ([tagName isEqualToString:[self defaultTagNameForKey:FTCoreTextTagLink]]) {
                    newNode.isLink = YES;
                }
                else if ([tagName isEqualToString:[self defaultTagNameForKey:FTCoreTextTagBullet]]) {
                    newNode.isBullet = YES;
                    
                    NSString *appendedString = [NSString stringWithFormat:@"%@\t", newNode.style.bulletCharacter];
                    
                    [processedString insertString:appendedString atIndex:tagRange.location + tagRange.length];
                    
                    //bullet styling
                    FTCoreTextStyle *bulletStyle = [FTCoreTextStyle new];
                    bulletStyle.name = @"_FTBulletStyle";
                    bulletStyle.font = newNode.style.bulletFont;
                    bulletStyle.color = newNode.style.bulletColor;
                    bulletStyle.applyParagraphStyling = NO;
                    bulletStyle.paragraphInset = UIEdgeInsetsMake(0, 0, 0, newNode.style.paragraphInset.left);
                    
                    FTCoreTextNode *bulletNode = [FTCoreTextNode new];
                    bulletNode.style = bulletStyle;
                    bulletNode.styleRange = NSMakeRange(tagRange.location, [appendedString length]);
                    
                    [newNode addSubnode:bulletNode];
                }
                else if ([tagName isEqualToString:[self defaultTagNameForKey:FTCoreTextTagImage]]) {
                    newNode.isImage = YES;
                }
                
                [processedString replaceCharactersInRange:tagRange withString:@""];
                
                [currentSupernode addSubnode:newNode];
                
                currentSupernode = newNode;
                
                remainingRange.location = tagRange.location;
                remainingRange.length = [processedString length] - tagRange.location;
            }
                break;
            case FTCoreTextTagTypeClose: //闭合标签
            {
                if ((![currentSupernode.style.name isEqualToString:[self defaultTagNameForKey:FTCoreTextTagDefault]] && ![currentSupernode.style.name isEqualToString:tagName]) ) {
                    if (_verbose) NSLog(@"FTCoreTextView :%@ - Closing tag '%@' at range %@ doesn't match open tag '%@' - aborting rendering", self, fullTag, NSStringFromRange(tagRange), currentSupernode.style.name);
                    return;
                }
                
                currentSupernode.isClosed = YES;
                if (currentSupernode.isLink) {
                    //replace active string with url text
                    
                    NSRange elementContentRange = NSMakeRange(currentSupernode.startLocation, tagRange.location - currentSupernode.startLocation);
                    NSString *elementContent = [processedString substringWithRange:elementContentRange];
                    NSRange pipeRange = [elementContent rangeOfString:@"|"];
                    NSString *urlString = nil;
                    NSString *urlDescription = nil;
                    if (pipeRange.location != NSNotFound) {
                        //url地址
                        urlString = [elementContent substringToIndex:pipeRange.location] ;
                        //标签文本
                        urlDescription = [elementContent substringFromIndex:pipeRange.location + 1];
                    }
                    
                    [processedString replaceCharactersInRange:NSMakeRange(elementContentRange.location, elementContentRange.length + tagRange.length) withString:urlDescription];
                    if (!([[urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] hasPrefix:@"http://"] || [[urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] hasPrefix:@"https://"]))
                    {
                        urlString = [NSString stringWithFormat:@"http://%@", urlString];
                    }
                    NSURL *url = [NSURL URLWithString:[urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    NSRange urlDescriptionRange = NSMakeRange(elementContentRange.location, [urlDescription length]);
                    [_URLs setObject:url forKey:NSStringFromRange(urlDescriptionRange)];
                    
                    currentSupernode.styleRange = urlDescriptionRange;
                }
                else if (currentSupernode.isImage) {
                    //replace active string with emptySpace
					
                    NSRange elementContentRange = NSMakeRange(currentSupernode.startLocation, tagRange.location - currentSupernode.startLocation);
                    NSString *elementContent = [processedString substringWithRange:elementContentRange];
                    UIImage *img =nil;
                    if ([elementContent hasPrefix:@"base64:"])//图片流
                    {
                        NSData *myImgData = [NSData ftct_dataWithBase64EncodedString:[elementContent substringFromIndex:7]];
                        img = [UIImage imageWithData:myImgData];
                        if (img) {
                            NSString *lines = @"\n";
                            float leading = img.size.height;
                            // float width=img.size.width;
                            currentSupernode.style.leading = leading;
                            
                            currentSupernode.imageName = elementContent;
                            [processedString replaceCharactersInRange:NSMakeRange(elementContentRange.location, elementContentRange.length + tagRange.length) withString:lines];
                            
                            [_images addObject:currentSupernode];
                            currentSupernode.styleRange = NSMakeRange(elementContentRange.location, [lines length]);
                            
                        }
                        else {
                            if (_verbose) NSLog(@"FTCoreTextView :%@ - Couldn't find image '%@' in main bundle", self, [NSValue valueWithRange:elementContentRange]);
                            [processedString replaceCharactersInRange:tagRange withString:@""];
                        }

                        
                        
                    }
                    else //从网络获取图片
                    {
                        
                      
                        if (elementContent&&elementContent.length>0) {
                            NSString *lines = @"\n";
                            float leading = DEFAULT_NET_IMAGE_HEIGHT;
                           
                            currentSupernode.style.leading = leading;
                            
                            currentSupernode.imageName = elementContent;
                            [processedString replaceCharactersInRange:NSMakeRange(elementContentRange.location, elementContentRange.length + tagRange.length) withString:lines];
                            
                            [_images addObject:currentSupernode];
                            currentSupernode.styleRange = NSMakeRange(elementContentRange.location, [lines length]);
                            
                        }
                        else {
                            if (_verbose) NSLog(@"FTCoreTextView :%@ - Couldn't find image '%@' in main bundle", self, [NSValue valueWithRange:elementContentRange]);
                            [processedString replaceCharactersInRange:tagRange withString:@""];
                        }

                        
                        
                        
                        
                    }
                    
                 }
                else {
                    currentSupernode.styleRange = NSMakeRange(currentSupernode.startLocation, tagRange.location - currentSupernode.startLocation);
                    [processedString replaceCharactersInRange:tagRange withString:@""];
                }
                
                if ([currentSupernode.style.appendedCharacter length] > 0) {
                    [processedString insertString:currentSupernode.style.appendedCharacter atIndex:currentSupernode.styleRange.location + currentSupernode.styleRange.length];
                    NSRange newStyleRange = currentSupernode.styleRange;
                    newStyleRange.length += [currentSupernode.style.appendedCharacter length];
                    currentSupernode.styleRange = newStyleRange;
                }
                
                if (style.paragraphInset.top > 0) { //有段落间距
                    if (![style.name isEqualToString:[self defaultTagNameForKey:FTCoreTextTagBullet]] ||  [[currentSupernode previousNode].style.name isEqualToString:[self defaultTagNameForKey:FTCoreTextTagBullet]]) {
                        
                        //fix: add a new line for each new line and set its height to 'top' value
                        //插入顶部一个新行
                        [processedString insertString:@"\n" atIndex:currentSupernode.startLocation];
                        NSRange topSpacingStyleRange = NSMakeRange(currentSupernode.startLocation, [@"\n" length]);
                        FTCoreTextStyle *topSpacingStyle = [[FTCoreTextStyle alloc] init];
                        topSpacingStyle.name = [NSString stringWithFormat:@"_FTTopSpacingStyle_%@", currentSupernode.style.name];
                        topSpacingStyle.minLineHeight = currentSupernode.style.paragraphInset.top;
                        topSpacingStyle.maxLineHeight = currentSupernode.style.paragraphInset.top;
                        FTCoreTextNode *topSpacingNode = [[FTCoreTextNode alloc] init];
                        topSpacingNode.style = topSpacingStyle;
                        
                        topSpacingNode.styleRange = topSpacingStyleRange;
                        
                        [currentSupernode.supernode insertSubnode:topSpacingNode beforeNode:currentSupernode];
                        //递归调整文字位置
                        [currentSupernode adjustStylesAndSubstylesRangesByRange:topSpacingStyleRange];
                    }
                }
                
                remainingRange.location = currentSupernode.styleRange.location + currentSupernode.styleRange.length;
                remainingRange.length = [processedString length] - remainingRange.location;
                currentSupernode = currentSupernode.supernode;
            }
                break;
            case FTCoreTextTagTypeSelfClose:
            {
                FTCoreTextNode *newNode = [FTCoreTextNode new];
                newNode.style = style;
                [processedString replaceCharactersInRange:tagRange withString:newNode.style.appendedCharacter];
                newNode.styleRange = NSMakeRange(tagRange.location, [newNode.style.appendedCharacter length]);
                newNode.startLocation = tagRange.location;
                [currentSupernode addSubnode:newNode];
				
                if (style.block)
                {
                    NSDictionary *blockDict = [NSDictionary dictionaryWithObjectsAndKeys:tagsComponents,@"components", [NSValue valueWithRange:NSMakeRange(tagRange.location, newNode.style.appendedCharacter.length)],@"range", nil];
                    style.block(blockDict);
                }
                remainingRange.location = tagRange.location;
                remainingRange.length = [processedString length] - tagRange.location;
            }
                break;
        }
	}
	
	rootNode.styleRange = NSMakeRange(0, [processedString length]);
	
	self.rootNode = rootNode;
	self.processedString = processedString;
}

/*!
 * @abstract Remove all the tags and return a clean text to be used
 *
 */

+ (NSString *)stripTagsForString:(NSString *)string
{
    FTCoreTextView *instance = [[FTCoreTextView alloc] initWithFrame:CGRectZero];
    [instance setText:string];
    [instance processText];
    NSString *result = [instance.processedString copy];
    return result;
}

/*!
 * @abstract divide the text in different pages according to the tags <_page/> found
 
 
 *
 */

+ (NSArray *)pagesFromText:(NSString *)string
{
    FTCoreTextView *instance = [[FTCoreTextView alloc] initWithFrame:CGRectZero];
    NSArray *result = [instance divideTextInPages:string];
    return (NSArray *)result;
}

/*!
 * @abstract divide the text in different pages according to the tags <_page/> found
 *
 */

- (NSMutableArray *)divideTextInPages:(NSString *)string
{
    NSMutableArray *result = [NSMutableArray array];
    NSInteger prevStart = 0;
    while (YES) {
        NSRange rangeStart = [string rangeOfString:[NSString stringWithFormat:@"<%@/>", [self defaultTagNameForKey:FTCoreTextTagPage]]];
		if (rangeStart.location == NSNotFound) rangeStart = [string rangeOfString:[NSString stringWithFormat:@"<%@ />", [self defaultTagNameForKey:FTCoreTextTagPage]]];
		
        if (rangeStart.location != NSNotFound) {
            NSString *page = [string substringWithRange:NSMakeRange(prevStart, rangeStart.location)];
            [result addObject:page];
            string = [string stringByReplacingCharactersInRange:rangeStart withString:@""];
            prevStart = rangeStart.location;
        }
        else {
            NSString *page = [string substringWithRange:NSMakeRange(prevStart, (string.length - prevStart))];
            [result addObject:page];
            break;
        }
    }
    return result;
}

#pragma mark Styling

- (void)addStyle:(FTCoreTextStyle *)style
{
	[_styles setObject:[style copy] forKey:style.name];
	[self didMakeChanges];
    if ([self superview]) [self setNeedsDisplay];
}

- (void)addStyles:(NSArray *)styles
{
	for (FTCoreTextStyle *style in styles) {
		[_styles setObject:[style copy] forKey:style.name];
	}
	[self didMakeChanges];
    if ([self superview]) [self setNeedsDisplay];
}

- (void)removeAllStyles
{
	[_styles removeAllObjects];
	[self didMakeChanges];
    if ([self superview]) [self setNeedsDisplay];
}




//对去除标签后得字符串进行 CoreText属性的添加
- (void)applyStyle:(FTCoreTextStyle *)style inRange:(NSRange)styleRange onString:(NSMutableAttributedString **)attributedString
{
    //看看处理图像了吗
    
    
    
    
    //标签名字
    [*attributedString addAttribute:(id)FTCoreTextDataName
							  value:(id)style.name
							  range:styleRange];
    //前景颜色
	[*attributedString addAttribute:(id)kCTForegroundColorAttributeName
							  value:(id)style.color.CGColor
							  range:styleRange];
	//是否需要下划线
	if (style.isUnderLined) {
		NSNumber *underline = [NSNumber numberWithInt:kCTUnderlineStyleSingle];
		[*attributedString addAttribute:(id)kCTUnderlineStyleAttributeName
								  value:(id)underline
								  range:styleRange];
	}
	
	CTFontRef ctFont = CTFontCreateFromUIFont(style.font);
	//字体
	[*attributedString addAttribute:(id)kCTFontAttributeName
							  value:(__bridge id)ctFont
							  range:styleRange];
	CFRelease(ctFont);
	
	CTTextAlignment alignment = (CTTextAlignment)style.textAlignment;
	CGFloat maxLineHeight = style.maxLineHeight;//最大行高
	CGFloat minLineHeight = style.minLineHeight;//最小行高
	CGFloat paragraphLeading = style.leading;//段落之间的间距
	
	CGFloat paragraphSpacingBefore = style.paragraphInset.top;
	CGFloat paragraphSpacingAfter = style.paragraphInset.bottom;
	CGFloat paragraphFirstLineHeadIntent = style.paragraphInset.left;
	CGFloat paragraphHeadIntent = style.paragraphInset.left;
	CGFloat paragraphTailIntent = style.paragraphInset.right;
	
	//if (SYSTEM_VERSION_LESS_THAN(@"5.0")) {
	paragraphSpacingBefore = 0;
	//}
	
	CFIndex numberOfSettings = 9;
	CGFloat tabSpacing = 28.f;
	
	BOOL applyParagraphStyling = style.applyParagraphStyling;
	
	if ([style.name isEqualToString:[self defaultTagNameForKey:FTCoreTextTagBullet]]) {
		applyParagraphStyling = YES;
	}
	else if ([style.name isEqualToString:@"_FTBulletStyle"]) { //自定义符号
		applyParagraphStyling = YES;
		numberOfSettings++;
		tabSpacing = style.paragraphInset.right;
		paragraphSpacingBefore = 0;
		paragraphSpacingAfter = 0;
		paragraphFirstLineHeadIntent = 0;
		paragraphTailIntent = 0;
	}
	else if ([style.name hasPrefix:@"_FTTopSpacingStyle"]) {//加入了段落间距
		[*attributedString removeAttribute:(id)kCTParagraphStyleAttributeName range:styleRange];
	}
	
	if (applyParagraphStyling) {
		
		CTTextTabRef tabArray[] = { CTTextTabCreate(0, tabSpacing, NULL) };
		
		CFArrayRef tabStops = CFArrayCreate( kCFAllocatorDefault, (const void**) tabArray, 1, &kCFTypeArrayCallBacks );
		CFRelease(tabArray[0]);
		
		CTParagraphStyleSetting settings[] = {
			{kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment},
			{kCTParagraphStyleSpecifierMaximumLineHeight, sizeof(CGFloat), &maxLineHeight},
			{kCTParagraphStyleSpecifierMinimumLineHeight, sizeof(CGFloat), &minLineHeight},
			{kCTParagraphStyleSpecifierParagraphSpacingBefore, sizeof(CGFloat), &paragraphSpacingBefore},
			{kCTParagraphStyleSpecifierParagraphSpacing, sizeof(CGFloat), &paragraphSpacingAfter},
			{kCTParagraphStyleSpecifierFirstLineHeadIndent, sizeof(CGFloat), &paragraphFirstLineHeadIntent},
			{kCTParagraphStyleSpecifierHeadIndent, sizeof(CGFloat), &paragraphHeadIntent},
			{kCTParagraphStyleSpecifierTailIndent, sizeof(CGFloat), &paragraphTailIntent},
			{kCTParagraphStyleSpecifierLineSpacing, sizeof(CGFloat), &paragraphLeading},
			{kCTParagraphStyleSpecifierTabStops, sizeof(CFArrayRef), &tabStops}//always at the end
		};
		//设置行间距和换行模式都是设置一个属性：kCTParagraphStyleAttributeName，
		CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, numberOfSettings);
		[*attributedString addAttribute:(id)kCTParagraphStyleAttributeName
								  value:(__bridge id)paragraphStyle
								  range:styleRange];
		CFRelease(tabStops);
		CFRelease(paragraphStyle);
	}
}

#pragma mark - Object lifecycle

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame andAttributedString:nil];
}

- (id)initWithFrame:(CGRect)frame andAttributedString:(NSAttributedString *)attributedString
{
	self = [super initWithFrame:frame];
	if (self) {
		_attributedString = attributedString;
		[self doInit];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self doInit];
    }
    return self;
}

- (void)doInit
{
	// Initialization code
	_framesetter = NULL;
	_styles = [[NSMutableDictionary alloc] init];
	_URLs = [[NSMutableDictionary alloc] init];
    _images = [[NSMutableArray alloc] init];
	_verbose = YES;
	_highlightTouch = YES;
	self.opaque = YES;
	self.backgroundColor = [UIColor whiteColor];
	
    _clipViews=[NSMutableArray new];
    self.scaleX=2.0;
    self.scaleY=2.0f;
    
    
    /*
     当你想视图在放缩和重设尺寸的操作中重绘你也可以用UIViewContentModeRedraw内容模式。设置这个值绘强制系统调用视图的drawRect:方法来响应几何结构的变化。通常来讲，你应该尽可能的避免使用这个模式，同时你不应该在标准的系统视图中使用这个模式
    */
     self.contentMode = UIViewContentModeRedraw;
	
    
    [self setUserInteractionEnabled:YES];
	
	FTCoreTextStyle *defaultStyle = [FTCoreTextStyle styleWithName:FTCoreTextTagDefault];
	[self addStyle:defaultStyle];
	
	FTCoreTextStyle *linksStyle = [defaultStyle copy];
	linksStyle.color = [UIColor blueColor];
	linksStyle.name = FTCoreTextTagLink;
	[_styles setObject:[linksStyle copy] forKey:linksStyle.name];
	
	_defaultsTags = [NSMutableDictionary dictionaryWithObjectsAndKeys:FTCoreTextTagDefault, FTCoreTextTagDefault,
					 FTCoreTextTagLink, FTCoreTextTagLink,
					 FTCoreTextTagImage, FTCoreTextTagImage,
					 FTCoreTextTagPage, FTCoreTextTagPage,
					 FTCoreTextTagBullet, FTCoreTextTagBullet,
					 nil];
}

- (void)dealloc
{
	if (_framesetter) CFRelease(_framesetter);
	if (_path) CGPathRelease(_path);
}

#pragma mark - Custom Setters

- (void)setText:(NSString *)text
{
    _text = text;
	_coreTextViewFlags.textChangesMade = YES;
	[self didMakeChanges];
    if ([self superview]) [self setNeedsDisplay];
}

- (void)setPath:(CGPathRef)path
{
    _path = CGPathRetain(path);
	[self didMakeChanges];
    if ([self superview]) [self setNeedsDisplay];
}

- (void)setShadowColor:(UIColor *)shadowColor
{
	_shadowColor = shadowColor;
	if ([self superview]) [self setNeedsDisplay];
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
	_shadowOffset = shadowOffset;
	if ([self superview]) [self setNeedsDisplay];
}

#pragma mark - Custom Getters

//only here to assure compatibility with previous versions
//返回 FTCoreTextStyle数组
- (NSArray *)stylesArray
{
	return [self styles];
}

- (NSArray *)styles
{
	return [_styles allValues];
}
//根据什么标签属性返回对应的style
- (FTCoreTextStyle *)styleForName:(NSString *)tagName
{
	return [_styles objectForKey:tagName];
}

- (NSAttributedString *)attributedString
{
	if (!_coreTextViewFlags.updatedAttrString) {//如果没有更新过字符串
		_coreTextViewFlags.updatedAttrString = YES;
		
		if (_processedString == nil || _coreTextViewFlags.textChangesMade || !_coreTextViewFlags.updatedFramesetter) {
			_coreTextViewFlags.textChangesMade = NO;
			[self processText];
		}
		
		if (_processedString) {
			
			NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:_processedString];
			
            NSArray *arr=[_rootNode allSubnodes];
			for (FTCoreTextNode *node in [_rootNode allSubnodes]) {
				[self applyStyle:node.style inRange:node.styleRange onString:&string];
			}
			
			_attributedString = string;
		}
	}
	return _attributedString;
}

#pragma mark - View lifecycle

/*!
 * @abstract draw the actual coretext on the context
 *
 */

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	
    self.backgroundColor=[UIColor greenColor];
  	[self.backgroundColor setFill];
	CGContextFillRect(context, rect);
	
	[self updateFramesetterIfNeeded];//绘制文字
	
	CGMutablePathRef mainPath = CGPathCreateMutable();
	
    if (!_path) {
		CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
	}
	else {
		CGPathAddPath(mainPath, NULL, _path);
	}
	//CTFramesetterRef
	CTFrameRef drawFrame = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
	
	if (drawFrame == NULL) {
		if (_verbose) NSLog(@"f: %@", self.processedString);
	}
	else {
        //draw images
        if ([_images count] > 0){
            [self drawImages];
        }
		if (_shadowColor) {
			CGContextSetShadowWithColor(context, _shadowOffset, 0.f, _shadowColor.CGColor);
		}
		//旋转坐标
		CGContextSetTextMatrix(context, CGAffineTransformIdentity);
		CGContextTranslateCTM(context, 0, self.bounds.size.height);
		CGContextScaleCTM(context, 1.0, -1.0);
        
        
        
        
        
		// draw text
		CTFrameDraw(drawFrame, context);
	}
	// cleanup
	if (drawFrame) CFRelease(drawFrame);
	CGPathRelease(mainPath);
    if ([_delegate respondsToSelector:@selector(coreTextViewfinishedRendering:)]) {
        [_delegate coreTextViewfinishedRendering:self];
    }
}

- (void)drawImages
{
	CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
	
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
	//获取每行的起始位置，此时的左边是左下方为原点
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    NSInteger lineCount = [lines count];
    CGPoint origins[lineCount];
	
	CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
	
    //移除图像
    for (id clipView in self.clipViews) {
        [clipView removeFromSuperview];
    }
    [_clipViews removeAllObjects];

	FTCoreTextNode *imageNode = [_images objectAtIndex:0];
	
	for (int i = 0; i < lineCount; i++) {
		CGPoint baselineOrigin = origins[i];
		//the view is inverted, the y origin of the baseline is upside down
		baselineOrigin.y = CGRectGetHeight(self.frame) - baselineOrigin.y;
		
		CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
		CFRange cfrange = CTLineGetStringRange(line);
		
        
        if (cfrange.location > imageNode.styleRange.location) {
			CGFloat ascent, descent;
			
            CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
			//得到一行的frame
			CGRect lineFrame = CGRectMake(baselineOrigin.x, baselineOrigin.y - ascent, lineWidth, ascent + descent);
			
			CTTextAlignment alignment = (CTTextAlignment)imageNode.style.textAlignment;
            UIImage *img = nil;
            if ([imageNode.imageName hasPrefix:@"base64:"])
            {
                NSData *myImgData = [NSData ftct_dataWithBase64EncodedString:[imageNode.imageName substringFromIndex:7]];
                img = [UIImage imageWithData:myImgData];
                if (img) {
                    int x = 0;
                    if (alignment == kCTRightTextAlignment) x = (self.frame.size.width - img.size.width);
                    if (alignment == kCTCenterTextAlignment) x = ((self.frame.size.width - img.size.width) / 2);
                    
                    CGRect frame = CGRectMake(x, (lineFrame.origin.y - img.size.height), img.size.width, img.size.height);
                    
                    // adjusting frame
                    
                    UIEdgeInsets insets = imageNode.style.paragraphInset;
                    if (alignment != kCTCenterTextAlignment)
                        frame.origin.x = (alignment == kCTLeftTextAlignment)? insets.left : (self.frame.size.width - img.size.width - insets.right);
                    frame.origin.y += insets.top;
                    frame.size.width = ((insets.left + insets.right + img.size.width ) > self.frame.size.width)? self.frame.size.width : img.size.width;
                    
                    [img drawInRect:CGRectIntegral(frame)];
                  }

                
                
                
                
            }
            else
            {
                    if (imageNode.imageName) {
                       
                    int x = 0;
                        if (alignment == kCTRightTextAlignment){
                            x = (self.frame.size.width - DEFAULT_NET_IMAGE_WIDTH);
                        }
                        if (alignment == kCTCenterTextAlignment){
                            x = ((self.frame.size.width - DEFAULT_NET_IMAGE_WIDTH) / 2);
                        }
                    
                    CGRect frame = CGRectMake(x, (lineFrame.origin.y - DEFAULT_NET_IMAGE_HEIGHT), DEFAULT_NET_IMAGE_WIDTH, DEFAULT_NET_IMAGE_HEIGHT);
                    
                    // adjusting frame
                    
                    UIEdgeInsets insets = imageNode.style.paragraphInset;
                    if (alignment != kCTCenterTextAlignment)
                        frame.origin.x = (alignment == kCTLeftTextAlignment)? insets.left : (self.frame.size.width - DEFAULT_NET_IMAGE_WIDTH - insets.right);
                    frame.origin.y += insets.top;
                    frame.size.width = ((insets.left + insets.right + DEFAULT_NET_IMAGE_WIDTH ) > self.frame.size.width)? self.frame.size.width : DEFAULT_NET_IMAGE_WIDTH;
                       
                    NetImageView *imageView = [[NetImageView alloc] initWithFrame:frame];
                    imageView.mImageType = TImageType_CutFill;
                    [imageView GetImageByStr:imageNode.imageName];
                    [self addSubview:imageView];
                    [self.clipViews addObject:imageView];
                    imageView.tag=[self.clipViews indexOfObject:imageView];
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
                        [imageView addGestureRecognizer:tap];
                       
    
                }

            }
						
			NSInteger imageNodeIndex = [_images indexOfObject:imageNode];
			if (imageNodeIndex < [_images count] - 1) {
				imageNode = [_images objectAtIndex:imageNodeIndex + 1];
			}
			else {
				break;
			}
		}
	}
	CFRelease(ctframe);
    
    NSMutableArray *clipViewsFrames = [[NSMutableArray alloc] init];
    for (int i = 0; i < self.clipViews.count; i++) {
        [clipViewsFrames addObject:[NSValue valueWithCGRect:[self.clipViews[i] frame]]];
    }
    self.clipViewsFrames = [NSArray arrayWithArray:clipViewsFrames];

    
    
}
- (void)tap:(UITapGestureRecognizer *)tap
{
    NetImageView *tappedClipView = ( NetImageView *)tap.view;
    UIView * scrollView=[self superview];
    UIScrollView *vContent=(UIScrollView*)scrollView;
    UIView *baseView=vContent.superview;

    TuJiDetailVC *ctrl = [[TuJiDetailVC alloc] init];
    ctrl.hidesBottomBarWhenPushed = YES;
    ctrl.modalPresentationStyle = UIModalPresentationFullScreen;
    ctrl.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
   
    CGRect frame=[self.clipViewsFrames[tappedClipView.tag] CGRectValue];
    CGPoint center=CGPointMake(frame.origin.x+frame.size.width/2, frame.origin.y+frame.size.height/2);
    CGPoint point= [vContent convertPoint:center toView:baseView];
   //CGPoint point=CGPointMake([self.clipViewsFrames[tappedClipView.tag] CGRectValue].origin.x,[self.clipViewsFrames[tappedClipView.tag] CGRectValue].origin.y- vContent.contentOffset.y)  ;
    point=CGPointMake(point.x, point.y-64);
    ctrl.fromPoint=point;
    
    
    [(UIViewController *)self.delegate presentViewController:ctrl animated:NO completion:^{}];

    
    
    
    
    
    
    
    
  
//    UIView * scrollView=[self superview];
//    if([scrollView isKindOfClass:[UIScrollView class]]){
//    UIScrollView *vContent=(UIScrollView*)scrollView;
//    UIView *baseView=vContent.superview;
//    CGPoint center = CGPointZero;
//    //if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortrait) {
//        if(1==1){
//        //center = CGPointMake(tappedClipView.center.x,vContent.contentOffset.y+baseView.frame.size.height/2 );
//      
//        center= [vContent convertPoint:baseView.center fromView:baseView];
//        center=CGPointMake(tappedClipView.center.x, center.y);
//    
//    }
//    else{
//    
//    }
//        
//    [UIView animateWithDuration:0.3f animations:^{
//        if (CGPointEqualToPoint(center, tappedClipView.center)) {
//          //[((UIViewController *)(self.delegate)).navigationController setNavigationBarHidden:NO animated:YES];
//            [tappedClipView setTransFormScaleX:1 ScaleY:1];
//
//            tappedClipView.frame = [self.clipViewsFrames[tappedClipView.tag] CGRectValue];
//        } else {
//            
//  //          [((UIViewController *)(self.delegate)).navigationController setNavigationBarHidden:YES animated:YES];
//                [tappedClipView setTransFormScaleX:1 ScaleY:1];
//                [tappedClipView setTransFormScaleX:self.scaleX ScaleY:self.scaleY];
//                tappedClipView.center = center;
//            
//                [self bringSubviewToFront:tappedClipView];
//
//         
//            
//        }
//    }];
//    
//    [UIView animateWithDuration:0.3f animations:^{
//        [self.clipViews enumerateObjectsUsingBlock:^( UIView* clipView, NSUInteger idx, BOOL *stop) {
//            if (clipView != tappedClipView && CGPointEqualToPoint(center, clipView.center)) {
//                clipView.frame = [self.clipViewsFrames[clipView.tag] CGRectValue];
//              
//                    [self sendSubviewToBack:clipView];
//                
//            }
//        }];
//    }];
//  
//    
//    }
}





#pragma mark User Interaction

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(coreTextView:receivedTouchOnData:)]) {
		CGPoint point = [(UITouch *)[touches anyObject] locationInView:self];
		NSMutableArray *activeRects;
		NSDictionary *data = [self dataForPoint:point activeRects:&activeRects];
		if (data.count > 0) {
			NSMutableArray *selectedViews = [NSMutableArray new];
			for (NSString *rectString in activeRects) {
				CGRect rect = CGRectFromString(rectString);
				UIView *view = [[UIView alloc] initWithFrame:rect];
				view.layer.cornerRadius = 3;
				view.clipsToBounds = YES;
				view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
				[self addSubview:view];
				[selectedViews addObject:view];
			}
			self.touchedData = data;
			self.selectionsViews = selectedViews;
		}
	}
    
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	_touchedData = nil;
	[_selectionsViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	_selectionsViews = nil;
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_touchedData) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(coreTextView:receivedTouchOnData:)]) {
			if ([self.delegate respondsToSelector:@selector(coreTextView:receivedTouchOnData:)]) {
				[self.delegate coreTextView:self receivedTouchOnData:_touchedData];
			}
		}
		_touchedData = nil;
		[_selectionsViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		_selectionsViews = nil;
	}
	[super touchesEnded:touches withEvent:event];
}
//得到包含range的那一行的Rect
- (CGRect)getLineRectFromNSRange:(NSRange)range
{
    CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
	
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
	
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    NSInteger lineCount = [lines count];
    CGPoint origins[lineCount];
    if (lineCount != 0)
    {
		for (int i = 0; i < lineCount; i++)
        {
			CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
			CFRange lineRange= CTLineGetStringRange(line);
            if (range.location >= lineRange.location && (range.location + range.length)<= lineRange.location+lineRange.length)
            {
                CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
                CGPoint origin = origins[i];
                CGFloat ascent,descent,leading;
                CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
                origin.y = self.frame.size.height-(origin.y);
                CFRelease(ctframe);
                CGRect lineRect = CGRectMake(origin.x, origin.y+descent-(ascent+descent+1), lineWidth, ascent+descent+1);
                return lineRect;
            }
        }
	}
	CFRelease(ctframe);
    return CGRectMake(-1, -1, -1, -1);
}

//得到包含range的那一行的文本
- (NSString*)getTextInLineByRange:(NSRange)range
{
    CGMutablePathRef mainPath = CGPathCreateMutable();
    if (!_path) {
        CGPathAddRect(mainPath, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }
    else {
        CGPathAddPath(mainPath, NULL, _path);
    }
	
    CTFrameRef ctframe = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), mainPath, NULL);
    CGPathRelease(mainPath);
	
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(ctframe);
    CFRelease(ctframe);
    
    NSInteger lineCount = [lines count];
    if (lineCount != 0)
    {
		for (int i = 0; i < lineCount; i++)
        {
			CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
			CFRange lineRange= CTLineGetStringRange(line);
            if (range.location >= lineRange.location && (range.location + range.length)<= lineRange.location+lineRange.length)
            {
                NSRange lineNSRange= {lineRange.location,lineRange.length};
                NSString *correctString = [self.processedString substringWithRange:lineNSRange];
                return correctString;
            }
        }
	}
	
    return @"";
}

@end

























#pragma mark -
#pragma mark Custom categories implementation

@implementation NSString (FTCoreText)

- (NSString *)stringByAppendingTagName:(NSString *)tagName
{
	return [NSString stringWithFormat:@"<%@>%@</%@>", tagName, self, tagName];
}

@end



@implementation NSData (FTCoreTextAdditions)

//
// This method's implementation is copyied from Nick Lockwood's Base64
// Header of the method has been altered to prevent naming collisions
//
// Version 1.1
//
// Created by Nick Lockwood on 12/01/2012.
// Copyright (C) 2012 Charcoal Design
//
// Distributed under the permissive zlib License
// Get the latest version from here:
//
// https://github.com/nicklockwood/Base64
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
// claim that you wrote the original software. If you use this software
// in a product, an acknowledgment in the product documentation would be
// appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not be
// misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source distribution.
//

+ (NSData *)ftct_dataWithBase64EncodedString:(NSString *)string
{
    const char lookup[] =
    {
        99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 62, 99, 99, 99, 63,
        52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 99, 99, 99, 99, 99, 99,
        99, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 99, 99, 99, 99, 99,
        99, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 99, 99, 99, 99, 99
    };
    
    NSData *inputData = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSUInteger inputLength = [inputData length];
    const unsigned char *inputBytes = [inputData bytes];
    
    NSUInteger maxOutputLength = (inputLength / 4 + 1) * 3;
    NSMutableData *outputData = [NSMutableData dataWithLength:maxOutputLength];
    unsigned char *outputBytes = (unsigned char *)[outputData mutableBytes];
    
    NSUInteger accumulator = 0;
    NSUInteger outputLength = 0;
    unsigned char accumulated[] = {0, 0, 0, 0};
    for (NSUInteger i = 0; i < inputLength; i++)
    {
        unsigned char decoded = lookup[inputBytes[i] & 0x7F];
        if (decoded != 99)
        {
            accumulated[accumulator] = decoded;
            if (accumulator == 3)
            {
                outputBytes[outputLength++] = (accumulated[0] << 2) | (accumulated[1] >> 4);
                outputBytes[outputLength++] = (accumulated[1] << 4) | (accumulated[2] >> 2);
                outputBytes[outputLength++] = (accumulated[2] << 6) | accumulated[3];
            }
            accumulator = (accumulator + 1) % 4;
        }
    }
    
    //handle left-over data
    if (accumulator > 0) outputBytes[outputLength] = (accumulated[0] << 2) | (accumulated[1] >> 4);
    if (accumulator > 1) outputBytes[++outputLength] = (accumulated[1] << 4) | (accumulated[2] >> 2);
    if (accumulator > 2) outputLength++;
    
    //truncate data to match actual output length
    outputData.length = outputLength;
    return outputLength? outputData: nil;
}

@end