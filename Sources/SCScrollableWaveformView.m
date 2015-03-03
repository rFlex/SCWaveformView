//
//  SCScrollableWaveformView.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import "SCScrollableWaveformView.h"

@interface SCScrollableWaveformView() {
    BOOL _ignoreObservingEvents;
}

@end

@implementation SCScrollableWaveformView

static char *WaveformAssetContext = "WaveformAsset";
static char *WaveformTimeRangeContext = "WaveformTimeRange";
static char *ScrollableWaveformContentOffsetContext = "ScrollableWaveformContentOffset";

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self _commonInit];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self _commonInit];
    }
    
    return self;
}

- (void)_commonInit {    
    _waveformView = [SCWaveformView new];
    [_waveformView addObserver:self forKeyPath:@"asset" options:NSKeyValueObservingOptionNew context:WaveformAssetContext];
    [_waveformView addObserver:self forKeyPath:@"timeRange" options:NSKeyValueObservingOptionNew context:WaveformTimeRangeContext];
    
    [self addSubview:_waveformView];
    
    [self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:ScrollableWaveformContentOffsetContext];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"contentOffset"];
    
    [_waveformView removeObserver:self forKeyPath:@"asset"];
    [_waveformView removeObserver:self forKeyPath:@"timeRange"];
}

- (void)_updateWaveform {
    CMTime actualAssetTime = _waveformView.actualAssetDuration;
    if (CMTIME_IS_VALID(actualAssetTime)) {
        CGFloat ratio = self.contentOffset.x / self.contentSize.width;
        CMTime newStart = CMTimeMakeWithSeconds(
                                                CMTimeGetSeconds(actualAssetTime) * ratio,
                                                100000);
        
        if (CMTIME_COMPARE_INLINE(newStart, !=, _waveformView.timeRange.start)) {
//            NSLog(@"Updating timeRange to %fs", CMTimeGetSeconds(newStart));

            _waveformView.timeRange = CMTimeRangeMake(newStart, _waveformView.timeRange.duration);
        }
    }
}

static BOOL SCApproximateEquals(CGFloat x, CGFloat y, CGFloat x2, CGFloat y2) {
    CGFloat ratio = [UIScreen mainScreen].scale;
    
    if ((int)(x * ratio) != (int)(x2 * ratio)) {
        return NO;
    }
    
    if ((int)(y * ratio) != (int)(y2 * ratio)) {
        return NO;
    }
    
    return YES;
}

- (void)_updateScrollView {
    CMTimeRange timeRange = _waveformView.timeRange;
    CMTime assetDuration = _waveformView.actualAssetDuration;
    
    CGPoint newContentOffset;
    CGSize newContentSize;
    
    if (CMTIME_IS_INVALID(assetDuration) || CMTIME_IS_INVALID(timeRange.duration) || CMTIME_IS_POSITIVE_INFINITY(timeRange.duration)) {
        newContentOffset = CGPointMake(0, 0);
        newContentSize = self.bounds.size;
    } else {
        Float64 seconds = CMTimeGetSeconds(timeRange.duration);
        Float64 assetDurationSeconds = CMTimeGetSeconds(assetDuration);
        
        newContentSize = CGSizeMake(assetDurationSeconds / seconds * self.bounds.size.width, self.bounds.size.height);
        
        newContentOffset = CGPointMake(CMTimeGetSeconds(timeRange.start) / assetDurationSeconds * newContentSize.width, 0);
    }
    
    if (!SCApproximateEquals(newContentSize.width, newContentSize.height, self.contentSize.width, self.contentSize.height)) {
        _ignoreObservingEvents = YES;
        self.contentSize = newContentSize;
        _ignoreObservingEvents = NO;
    }
    
    if (!SCApproximateEquals(newContentOffset.x, newContentOffset.y, self.contentOffset.x, self.contentOffset.y)) {
//        NSLog(@"Updating contentOffset to %@", NSStringFromCGPoint(self.contentOffset));
        self.contentOffset = newContentOffset;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!_ignoreObservingEvents) {
       if (context == WaveformAssetContext || context == WaveformTimeRangeContext) {
           [self _updateScrollView];
        } else if (context == ScrollableWaveformContentOffsetContext) {
            [self _updateWaveform];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _waveformView.frame = self.bounds;
    
    [self _updateScrollView];
}

@end
