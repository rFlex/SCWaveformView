//
//  SCWaveformCache.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class SCWaveformCache;

@interface SCWaveformCache : NSObject

@property (strong, nonatomic) AVAsset *asset;

@property (readonly, nonatomic) CMTime timePerPixel;

@property (readonly, nonatomic) CMTime actualAssetDuration;

@property (readonly, nonatomic) NSUInteger actualNumberOfChannels;

@property (assign, nonatomic) NSUInteger maxChannels;

typedef void (^SCAudioBufferHandler)(int channel, int x, float sample, CMTime time);

- (BOOL)readTimeRange:(CMTimeRange)timeRange width:(CGFloat)width error:(NSError **)error;

- (void)readRange:(NSRange)range atTime:(CMTime)time handler:(SCAudioBufferHandler)handler;

- (void)invalidate;

@end
