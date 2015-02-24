//
//  SCWaveformView.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCWaveformCache.h"

@interface SCWaveformView : UIView

@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) UIColor *normalColor;
@property (strong, nonatomic) UIColor *progressColor;
@property (assign, nonatomic) CMTime progressTime;
@property (assign, nonatomic) BOOL antialiasingEnabled;

@property (strong, nonatomic) UIImage *generatedNormalImage;
@property (strong, nonatomic) UIImage *generatedProgressImage;

@property (assign, nonatomic) CMTimeRange timeRange;

// Ask the waveformview to generate the waveform right now
// instead of doing it in the next draw operation
- (void)generateWaveforms;

/**
 Render the waveform in the given context
 */
+ (BOOL)renderWaveformInContext:(CGContextRef)context asset:(AVAsset *)asset color:(UIColor *)color size:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled timeRange:(CMTimeRange)timeRange;

/**
 Returns the waveform as UIImage
 */
+ (UIImage *)generateWaveformImageWithAsset:(AVAsset *)asset color:(UIColor *)color size:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled timeRange:(CMTimeRange)timeRange;

/**
 Render the waveform in the given context using a cache that can be used later to make the rendering faster
 */
+ (BOOL)renderWaveformInContext:(CGContextRef)context cache:(SCWaveformCache *)cache color:(UIColor *)color size:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled timeRange:(CMTimeRange)timeRange;

/**
 Returns the waveform as UIImage using a cache that can be used later to make the rendering faster
 */
+ (UIImage *)generateWaveformImageWithCache:(SCWaveformCache *)cache color:(UIColor *)color size:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled timeRange:(CMTimeRange)timeRange;

@end
