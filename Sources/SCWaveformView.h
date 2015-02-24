//
//  SCWaveformView.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

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

// Render the waveform on a specified context
+ (void)renderWaveformInContext:(CGContextRef)context asset:(AVAsset *)asset withColor:(UIColor *)color andSize:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled;

// Generate a waveform image for an asset
+ (UIImage*)generateWaveformImage:(AVAsset*)asset withColor:(UIColor*)color andSize:(CGSize)size antialiasingEnabled:(BOOL)antialiasingEnabled;

@end
