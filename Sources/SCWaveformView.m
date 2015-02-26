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

@interface SCWaveformLayer : CALayer

@property (assign, nonatomic) CMTime waveformTime;

@end

@implementation SCWaveformLayer


@end

@interface SCWaveformView() {
    SCWaveformCache *_cache;
    NSMutableArray *_waveformLayers;
    BOOL _needsLayout;
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
    _precision = 1;
    _lineWidthRatio = 1;

    _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    _progressTime = kCMTimeZero;
    
    _cache = [SCWaveformCache new];
    _waveformLayers = [NSMutableArray new];
    
    self.normalColor = [UIColor blueColor];
    self.progressColor = [UIColor redColor];
    
    self.layer.shouldRasterize = NO;
}

- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)event {
    return [NSNull null];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat pixelRatio = [UIScreen mainScreen].scale * _precision;
    NSUInteger numberOfLayers = (NSInteger)round(pixelRatio * self.bounds.size.width);
    
    while (_waveformLayers.count < numberOfLayers) {
        SCWaveformLayer *layer = [SCWaveformLayer new];
        layer.delegate = self;
        
        [self.layer addSublayer:layer];
        
        [_waveformLayers addObject:layer];
    }
    
    while (_waveformLayers.count > numberOfLayers) {
        CALayer *layer = [_waveformLayers lastObject];
        [_waveformLayers removeLastObject];
        
        [layer removeFromSuperlayer];
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    CGSize size = self.bounds.size;
    size.width *= pixelRatio;
    
    [self renderWaveformWithSize:size pixelRatio:pixelRatio];
    
    [CATransaction commit];
    _needsLayout = NO;
}

- (BOOL)renderWaveformWithSize:(CGSize)size pixelRatio:(CGFloat)pixelRatio {
    float halfGraphHeight = size.height / 2;
    
    NSError *error = nil;
    
    __block BOOL reachedProgressPoint = NO;
    __block NSInteger firstIdx = -1;
    __block NSInteger lastIdx = -1;
    
    CGColorRef normalColor = _normalColor.CGColor;
    CGColorRef progressColor = _progressColor.CGColor;
    
    BOOL read = [_cache readTimeRange:_timeRange width:size.width error:&error handler:^(CGFloat x, float sample, CMTime time) {
        NSInteger idx = (NSInteger)round(x);
        
        if (idx < _waveformLayers.count) {
            if (!reachedProgressPoint && CMTIME_COMPARE_INLINE(time, >=, self.progressTime)) {
                reachedProgressPoint = YES;
            }
            
            float pixelHeight = halfGraphHeight * (1 - sample / noiseFloor);
            
            if (pixelHeight < 0) {
                pixelHeight = 0;
            }
            
            if (firstIdx == -1) {
                firstIdx = idx;
            }
            lastIdx = idx;
            
            SCWaveformLayer *layer = [_waveformLayers objectAtIndex:idx];
            CGColorRef destColor = nil;
            
            if (reachedProgressPoint) {
                destColor = normalColor;
            } else {
                destColor = progressColor;
            }
            
            if (layer.backgroundColor != destColor) {
                layer.backgroundColor = destColor;
            }
            
            CGRect newRect = CGRectMake(x / pixelRatio, halfGraphHeight - pixelHeight, _lineWidthRatio / pixelRatio, pixelHeight * 2);
            
            if (!CGRectEqualToRect(layer.frame, newRect)) {
                layer.frame = newRect;
            }
            
            layer.waveformTime = time;

        }
    }];
    
    CGColorRef clearColor = [UIColor clearColor].CGColor;
    
    if (firstIdx != -1) {
        for (NSInteger i = 0; i < firstIdx; i++) {
            CALayer *layer = [_waveformLayers objectAtIndex:i];
            layer.backgroundColor = clearColor;
        }
    }
    
    if (lastIdx != -1) {
        for (NSInteger i = lastIdx + 1; i < _waveformLayers.count; i++) {
            CALayer *layer = [_waveformLayers objectAtIndex:i];
            layer.backgroundColor = clearColor;
        }
    }
    
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

- (void)_updateColors {
    if (!_needsLayout) {
        CGColorRef normalColor = _normalColor.CGColor;
        CGColorRef progressColor = _progressColor.CGColor;
        CGColorRef destColor = progressColor;
        CGColorRef clearColor = [UIColor clearColor].CGColor;
        
        for (SCWaveformLayer *layer in _waveformLayers) {
            if (layer.backgroundColor != clearColor) {
                if (destColor != normalColor && CMTIME_COMPARE_INLINE(layer.waveformTime, >, _progressTime)) {
                    destColor = normalColor;
                }
                
                if (layer.backgroundColor != destColor) {
                    layer.backgroundColor = destColor;
                }                
            }
        }
    }
}

- (void)setNormalColor:(UIColor *)normalColor {
    _normalColor = normalColor;

    [self _updateColors];
}

- (void)setProgressColor:(UIColor *)progressColor {
    _progressColor = progressColor;
    
    [self _updateColors];
}

- (AVAsset *)asset {
    return _cache.asset;
}

- (void)setAsset:(AVAsset *)asset {
    [self willChangeValueForKey:@"asset"];
    
    _cache.asset = asset;

    [self setNeedsLayout];
    
    [self didChangeValueForKey:@"asset"];
}

- (void)setNeedsLayout {
    _needsLayout = YES;
    [super setNeedsLayout];
}

- (void)setProgressTime:(CMTime)progressTime {
    _progressTime = progressTime;
    
    [self _updateColors];
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

    [self setNeedsLayout];
    
    [self didChangeValueForKey:@"timeRange"];
}

- (void)setPrecision:(CGFloat)precision {
    _precision = precision;
    
    [self setNeedsLayout];
}

- (void)setLineWidthRatio:(CGFloat)lineWidthRatio {
    _lineWidthRatio = lineWidthRatio;
    
    [self setNeedsLayout];
}

@end
