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
@property (assign, nonatomic) BOOL antialiasingEnabled;

@property (assign, nonatomic) BOOL needsDisplayOnProgressTimeChange;

@property (assign, nonatomic) CMTimeRange timeRange;

@end
