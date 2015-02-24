//
//  SCScrollableWaveformView.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import "SCScrollableWaveformView.h"

@interface SCScrollableWaveformView() {
    BOOL _updatingScrollView;
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
    NSLog(@"CALLING COMMON INIT");
    
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
    if (CMTIME_IS_VALID(_waveformView.asset.duration)) {
        CGFloat ratio = self.contentOffset.x / self.contentSize.width;
        CMTime newStart = CMTimeMakeWithSeconds(
                                                CMTimeGetSeconds(_waveformView.asset.duration) * ratio,
                                                10000);
        _waveformView.timeRange = CMTimeRangeMake(newStart, _waveformView.timeRange.duration);
    }
}

- (void)_updateScrollView {
    CMTimeRange timeRange = _waveformView.timeRange;
    CMTime assetDuration = _waveformView.asset.duration;
    
    if (CMTIME_IS_INVALID(assetDuration) || CMTIME_IS_INVALID(timeRange.duration) || CMTIME_IS_POSITIVE_INFINITY(timeRange.duration)) {
        _updatingScrollView = YES;
        
        self.contentOffset = CGPointMake(0, 0);
        self.contentSize = self.bounds.size;
        
        _updatingScrollView = NO;
    } else {
        Float64 seconds = CMTimeGetSeconds(timeRange.duration);
        self.contentSize = CGSizeMake(CMTimeGetSeconds(assetDuration) / seconds * self.bounds.size.width, self.bounds.size.height);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!_updatingScrollView) {
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
