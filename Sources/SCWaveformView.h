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
#import "SCScrollableWaveformView.h" // For convenience

@interface SCWaveformView : UIView

@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) UIColor *normalColor;
@property (strong, nonatomic) UIColor *progressColor;
@property (assign, nonatomic) CMTime progressTime;

@property (assign, nonatomic) CGFloat precision;
@property (assign, nonatomic) CGFloat lineWidthRatio;

@property (assign, nonatomic) CMTimeRange timeRange;

/**
 The first audio channel index to render.
 Default is 0
 */
@property (assign, nonatomic) NSUInteger channelStartIndex;

/**
 The max number of channels to render. You can set that to 2
 to render a stereo waveform.
 Default is 1.
 */
@property (assign, nonatomic) NSUInteger maxChannels;

@property (readonly, nonatomic) CGSize waveformSize;

@property (readonly, nonatomic) CMTime actualAssetDuration;

@end
