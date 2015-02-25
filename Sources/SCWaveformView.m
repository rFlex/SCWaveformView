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
    CGPathRef _progressPath;
    CGPathRef _normalPath;
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
    _precision = 1;
    self.normalColor = [UIColor blueColor];
    self.progressColor = [UIColor redColor];
    _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    _progressTime = kCMTimeZero;
    
    _cache = [SCWaveformCache new];
}

void SCRenderPixelWaveformInPath(CGMutablePathRef path, float halfGraphHeight, float sample, float x) {
    float pixelHeight = halfGraphHeight * (1 - sample / noiseFloor);
    
    if (pixelHeight < 0) {
        pixelHeight = 0;
    }
    
    CGPathMoveToPoint(path, nil, x, halfGraphHeight - pixelHeight);
    CGPathAddLineToPoint(path, nil, x, halfGraphHeight + pixelHeight);
}

- (BOOL)renderWaveformWithSize:(CGSize)size pixelRatio:(CGFloat)pixelRatio {
    float halfGraphHeight = (size.height / 2 * pixelRatio);
    
    NSError *error = nil;
    
    __block BOOL reachedProgressPoint = NO;
    CGMutablePathRef normalPath = CGPathCreateMutable();
    CGMutablePathRef progressPath = CGPathCreateMutable();
    __block CGMutablePathRef currentPath = progressPath;
    
    BOOL read = [_cache readTimeRange:_timeRange width:size.width * pixelRatio error:&error handler:^(CGFloat x, float sample, CMTime time) {
        if (!reachedProgressPoint && CMTIME_COMPARE_INLINE(time, >=, self.progressTime)) {
            reachedProgressPoint = YES;
            currentPath = normalPath;
        }
        
        SCRenderPixelWaveformInPath(currentPath, halfGraphHeight / pixelRatio, sample, x / pixelRatio);
    }];
    
    _normalPath = normalPath;
    _progressPath = progressPath;
    
    return read;
}

- (UIImage *)generateWaveformImageWithSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size.width, size.height), NO, 1);
    
//    [self renderWaveformInContext:UIGraphicsGetCurrentContext() size:size];
    
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
    
    CGFloat pixelRatio = rect.size.width / CGContextConvertSizeToUserSpace(ctx, rect.size).width * _precision;
    
    CGContextSetAllowsAntialiasing(ctx, _antialiasingEnabled);
    CGContextSetLineWidth(ctx, 1.0 / pixelRatio);

    CGContextSetStrokeColorWithColor(ctx, _progressColor.CGColor);
    
    if (_progressPath == nil) {

        [self renderWaveformWithSize:rect.size pixelRatio:pixelRatio];
    }
    
    CGContextAddPath(ctx, _progressPath);
    
    CGContextStrokePath(ctx);

    CGContextSetStrokeColorWithColor(ctx, _normalColor.CGColor);
    
    CGContextAddPath(ctx, _normalPath);
    
    CGContextStrokePath(ctx);
    
    [super drawRect:rect];
}

- (void)_invalidatePaths {
    if (_normalPath != nil) {
        CGPathRelease(_normalPath);
        _normalPath = nil;
    }
    if (_progressPath != nil) {
        CGPathRelease(_progressPath);
        _progressPath = nil;
    }
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
    
    [self _invalidatePaths];
    [self setNeedsDisplay];
    
    [self didChangeValueForKey:@"asset"];
}

- (void)setProgressTime:(CMTime)progressTime {
    _progressTime = progressTime;
    
    [self _invalidatePaths];
    
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
    
    [self _invalidatePaths];
    [self setNeedsDisplay];
    
    [self didChangeValueForKey:@"timeRange"];
}

- (void)setPrecision:(CGFloat)precision {
    _precision = precision;
    
    [self _invalidatePaths];
    [self setNeedsDisplay];
}

@end
