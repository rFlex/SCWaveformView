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

@interface SCWaveformLayerDelegate : NSObject

@end

@implementation SCWaveformLayerDelegate

- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)event {
    return [NSNull null];
}

@end

@interface SCWaveformView() {
//    SCWaveformCache *_cache;
    NSMutableArray *_waveformLayers;
    SCWaveformLayerDelegate *_waveformLayersDelegate;
    CALayer *_waveformSuperlayer;
    NSInteger _firstVisibleIdx;
    BOOL _graphDirty;
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

    _waveformLayersDelegate = [SCWaveformLayerDelegate new];
    _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    _progressTime = kCMTimeZero;
    
    _cache = [SCWaveformCache new];
    _waveformLayers = [NSMutableArray new];
    _graphDirty = YES;
    
    self.normalColor = [UIColor blueColor];
    self.progressColor = [UIColor redColor];
    
    self.layer.shouldRasterize = NO;
    
    _waveformSuperlayer = [CALayer layer];
    _waveformSuperlayer.anchorPoint = CGPointMake(0, 0);
    _waveformSuperlayer.delegate = _waveformLayersDelegate;
    
    [self.layer addSublayer:_waveformSuperlayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat pixelRatio = scale * _precision;
    CGSize size = self.bounds.size;
    size.width *= pixelRatio;
    
    NSError *error = nil;
    if ([_cache readTimeRange:_timeRange width:size.width error:&error]) {
        NSUInteger numberOfLayers = (NSUInteger)ceil(pixelRatio * self.bounds.size.width) + 1;
        
        while (_waveformLayers.count < numberOfLayers) {
            SCWaveformLayer *layer = [SCWaveformLayer new];
            layer.anchorPoint = CGPointMake(0, 0);
            layer.delegate = _waveformLayersDelegate;
            
            [_waveformSuperlayer addSublayer:layer];
            
            [_waveformLayers addObject:layer];
        }
        
        while (_waveformLayers.count > numberOfLayers) {
            CALayer *layer = [_waveformLayers lastObject];
            [_waveformLayers removeLastObject];
            
            [layer removeFromSuperlayer];
        }
        
        CGRect waveformSuperlayerFrame = _waveformSuperlayer.frame;
        waveformSuperlayerFrame.origin.y = 0;
        
        waveformSuperlayerFrame.size = self.waveformSize;
        if (!CGSizeEqualToSize(waveformSuperlayerFrame.size, _waveformSuperlayer.frame.size)) {
            _graphDirty = YES;
        }
        
        
        CMTime timePerPixel = CMTimeMultiplyByRatio(_timeRange.duration, 1, size.width);
        double startRatio = CMTimeGetSeconds(_timeRange.start) / CMTimeGetSeconds(timePerPixel);
        NSInteger newFirstVisibleIdx = floor(startRatio);
        waveformSuperlayerFrame.origin.x = -startRatio / pixelRatio;
        NSRange dirtyRange = NSMakeRange(0, _waveformLayers.count);
        
        if (!_graphDirty) {
            int offset = newFirstVisibleIdx - _firstVisibleIdx;
            int absOffset = abs(offset);
            
            if (absOffset < _waveformLayers.count / 2) {
                dirtyRange.length = absOffset;
                
                if (offset > 0) {
                    dirtyRange.location = _waveformLayers.count - offset;
                    for (int i = 0; i < offset; i++) {
                        SCWaveformLayer *layer = [_waveformLayers objectAtIndex:0];
                        [_waveformLayers removeObjectAtIndex:0];
                        [_waveformLayers addObject:layer];
                    }
                } else if (offset < 0) {
                    dirtyRange.location = 0;
                    for (int i = offset; i < 0; i++) {
                        SCWaveformLayer *layer = [_waveformLayers lastObject];
                        [_waveformLayers removeLastObject];
                        [_waveformLayers insertObject:layer atIndex:0];
                    }
                }
            }
        }
        
        _firstVisibleIdx = newFirstVisibleIdx;
        _waveformSuperlayer.frame = waveformSuperlayerFrame;
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        CGColorRef normalColor = _normalColor.CGColor;
        CGColorRef progressColor = _progressColor.CGColor;
        __block BOOL reachedProgressPoint = NO;
        CGFloat halfGraphHeight = size.height / 2;
        CGFloat bandWidth = 1 / pixelRatio;
        CGFloat pointSize = 1.0 / scale / 2;
        CMTime assetDuration = [_cache actualAssetDuration];
        //    NSLog(@"Computing bands %d to %d with duration %fs", dirtyRange.location, dirtyRange.location + dirtyRange.length, CMTimeGetSeconds(_timeRange.duration));
        
        [_cache readRange:dirtyRange atTime:_timeRange.start handler:^(int idx, float sample, CMTime time) {
            if (idx < _waveformLayers.count) {
                if (!reachedProgressPoint && CMTIME_COMPARE_INLINE(time, >=, self.progressTime)) {
                    reachedProgressPoint = YES;
                }
                
                float pixelHeight = halfGraphHeight * (1 - sample / noiseFloor);
                
                if (pixelHeight < pointSize) {
                    if (CMTIME_COMPARE_INLINE(time, <, kCMTimeZero) || CMTIME_COMPARE_INLINE(time, >, assetDuration)) {
                        pixelHeight = 0;
                    } else {
                        pixelHeight = pointSize;
                    }
                }
                
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
                
                layer.frame = CGRectMake((newFirstVisibleIdx + idx) * bandWidth, halfGraphHeight - pixelHeight, _lineWidthRatio / pixelRatio, pixelHeight * 2);
                
                layer.waveformTime = time;
            }

        }];

        _graphDirty = NO;
        
        [CATransaction commit];
    } else {
        if (error != nil) {
            NSLog(@"Unable to generate waveform: %@", error.localizedDescription);
        }
    }
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

- (void)_updateLayersColor:(BOOL)updateColor lineWidth:(BOOL)lineWidth {
    CGColorRef normalColor = _normalColor.CGColor;
    CGColorRef progressColor = _progressColor.CGColor;
    CGColorRef destColor = progressColor;
    CGFloat pixelRatio = [UIScreen mainScreen].scale * _precision;
    
    for (SCWaveformLayer *layer in _waveformLayers) {
        if (updateColor) {
            if (destColor != normalColor && CMTIME_COMPARE_INLINE(layer.waveformTime, >, _progressTime)) {
                destColor = normalColor;
            }
            
            if (layer.backgroundColor != destColor) {
                layer.backgroundColor = destColor;
            }
        }
        
        if (lineWidth) {
            CGRect bounds = layer.bounds;
            bounds.size.width = _lineWidthRatio / pixelRatio;
            layer.bounds = bounds;
        }
    }
}

- (void)setNormalColor:(UIColor *)normalColor {
    _normalColor = normalColor;

    [self _updateLayersColor:YES lineWidth:NO];
}

- (void)setProgressColor:(UIColor *)progressColor {
    _progressColor = progressColor;
    
    [self _updateLayersColor:YES lineWidth:NO];
}

- (AVAsset *)asset {
    return _cache.asset;
}

- (void)setAsset:(AVAsset *)asset {
    [self willChangeValueForKey:@"asset"];
    
    _cache.asset = asset;
    _graphDirty = YES;

    [self setNeedsLayout];
    
    [self didChangeValueForKey:@"asset"];
}

- (void)setProgressTime:(CMTime)progressTime {
    _progressTime = progressTime;
    
    [self _updateLayersColor:YES lineWidth:NO];
}

- (void)setTimeRange:(CMTimeRange)timeRange {
    [self willChangeValueForKey:@"timeRange"];
    
    if (CMTIME_COMPARE_INLINE(timeRange.duration, !=, _timeRange.duration)) {
        _graphDirty = YES;
    }
    
    _timeRange = timeRange;

    [self setNeedsLayout];
    
    [self didChangeValueForKey:@"timeRange"];
}

- (void)setPrecision:(CGFloat)precision {
    _precision = precision;
    
    _graphDirty = YES;
    
    [self setNeedsLayout];
}

- (void)setLineWidthRatio:(CGFloat)lineWidthRatio {
    _lineWidthRatio = lineWidthRatio;
    
    [self _updateLayersColor:NO lineWidth:YES];
}

- (CGSize)waveformSize {
    CMTimeRange timeRange = _timeRange;
    CMTime assetDuration = [_cache actualAssetDuration];

    if (CMTIME_IS_INVALID(assetDuration) || CMTIME_IS_INVALID(timeRange.duration) || CMTIME_IS_POSITIVE_INFINITY(timeRange.duration)) {
        return CGSizeZero;
    } else {
        Float64 seconds = CMTimeGetSeconds(timeRange.duration);
        Float64 assetDurationSeconds = CMTimeGetSeconds(assetDuration);
        
        return CGSizeMake(assetDurationSeconds / seconds * self.bounds.size.width, self.bounds.size.height);
    }
}

@end
