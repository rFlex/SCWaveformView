//
//  SCWaveformView.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import "SCWaveformView.h"
#import "SCWaveformCache.h"

#define absX(x) (x < 0 ? 0 - x : x)
#define minMaxX(x, mn, mx) (x <= mn ? mn : (x >= mx ? mx : x))
#define noiseFloor (-50.0)
#define decibel(amplitude) (20.0 * log10(absX(amplitude) / 32767.0))

@interface SCWaveformView() {
    SCWaveformCache *_cache;
}

@end

@implementation SCWaveformView

- (instancetype)init {
    self = [super init];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit {
    _needsDisplayOnProgressTimeChange = YES;
    self.normalColor = [UIColor blueColor];
    self.progressColor = [UIColor redColor];
    _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    _progressTime = kCMTimeZero;
    
    _cache = [SCWaveformCache new];
}

void SCRenderPixelWaveformInContext(CGContextRef context, float halfGraphHeight, float sample, float x) {
    float pixelHeight = halfGraphHeight * (1 - sample / noiseFloor);
    
    if (pixelHeight < 0) {
        pixelHeight = 0;
    }
    
    CGContextMoveToPoint(context, x, halfGraphHeight - pixelHeight);
    CGContextAddLineToPoint(context, x, halfGraphHeight + pixelHeight);
    CGContextStrokePath(context);
}

- (BOOL)renderWaveformInContext:(CGContextRef)context size:(CGSize)size {
    CGFloat pixelRatio = size.width / CGContextConvertSizeToUserSpace(context, size).width;
    
    float halfGraphHeight = (size.height / 2 * pixelRatio);
    
    NSError *error = nil;
    
    CGContextSetAllowsAntialiasing(context, _antialiasingEnabled);
    CGContextSetLineWidth(context, 1.0);
    
    CGContextSetStrokeColorWithColor(context, _progressColor.CGColor);
    CGContextSetFillColorWithColor(context, _progressColor.CGColor);
    __block BOOL reachedProgressPoint = NO;
    
    return [_cache readTimeRange:_timeRange width:size.width * pixelRatio error:&error handler:^(CGFloat x, float sample, CMTime time) {
        if (!reachedProgressPoint && CMTIME_COMPARE_INLINE(time, >=, self.progressTime)) {
            reachedProgressPoint = YES;
            CGContextSetStrokeColorWithColor(context, _normalColor.CGColor);
            CGContextSetFillColorWithColor(context, _normalColor.CGColor);
        }
        
        SCRenderPixelWaveformInContext(context, halfGraphHeight / pixelRatio, sample, x / pixelRatio);
    }];
}

- (UIImage *)generateWaveformImageWithSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size.width, size.height), NO, 1);
    
    [self renderWaveformInContext:UIGraphicsGetCurrentContext() size:size];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage*)recolorizeImage:(UIImage*)image withColor:(UIColor*)color {
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, imageRect, image.CGImage);
    [color set];
    UIRectFillUsingBlendMode(imageRect, kCGBlendModeSourceAtop);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextClearRect(ctx, rect);
    [self renderWaveformInContext:ctx size:rect.size];
    
    [super drawRect:rect];
}

- (void)setNormalColor:(UIColor *)normalColor {
    _normalColor = normalColor;
    [self setNeedsDisplay];
}

- (void)setProgressColor:(UIColor *)progressColor {
    _progressColor = progressColor;
    [self setNeedsDisplay];
}

- (AVAsset *)asset {
    return _cache.asset;
}

- (void)setAsset:(AVAsset *)asset {
    [self willChangeValueForKey:@"asset"];
    
    _cache.asset = asset;
    [self setNeedsDisplay];
    
    [self didChangeValueForKey:@"asset"];
}

- (void)setProgressTime:(CMTime)progressTime {
    _progressTime = progressTime;
    
    if (self.needsDisplayOnProgressTimeChange) {
        [self setNeedsDisplay];
    }
}

- (void)setAntialiasingEnabled:(BOOL)antialiasingEnabled {
    if (_antialiasingEnabled != antialiasingEnabled) {
        _antialiasingEnabled = antialiasingEnabled;
        [self setNeedsDisplay];        
    }
}

- (void)setTimeRange:(CMTimeRange)timeRange {
    [self willChangeValueForKey:@"timeRange"];
    
    _timeRange = timeRange;
    [self setNeedsDisplay];
    
    [self didChangeValueForKey:@"timeRange"];
}

@end
