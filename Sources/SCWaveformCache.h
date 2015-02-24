//
//  SCWaveformCache.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface SCWaveformCache : NSObject

@property (strong, nonatomic) AVAsset *asset;

typedef void (^SCAudioBufferHandler)(CGFloat x, double sample);

- (BOOL)readTimeRange:(CMTimeRange)timeRange width:(CGFloat)width error:(NSError **)error handler:(SCAudioBufferHandler)handler;

@end
