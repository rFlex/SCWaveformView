//
//  SCViewController.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import "SCViewController.h"
#import "SCWaveformView.h"

@interface SCViewController () {
    AVPlayer *_player;
    id _observer;
}

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.scrollableWaveformView.waveformView.precision = 1;
    self.scrollableWaveformView.waveformView.lineWidthRatio = 1;
    self.scrollableWaveformView.waveformView.normalColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1];
    self.scrollableWaveformView.waveformView.channelsPadding = 10;
    self.scrollableWaveformView.waveformView.progressColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"test" withExtension:@"m4a"] options:nil];
    
    self.scrollableWaveformView.alpha = 0.8;
    
    self.scrollableWaveformView.waveformView.asset = asset;
    CMTime progressTime = CMTimeMakeWithSeconds(
                                                self.slider.value * CMTimeGetSeconds(self.scrollableWaveformView.waveformView.asset.duration),
                                                100000);
    
    self.scrollableWaveformView.waveformView.timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(15, 10000), progressTime);
    
    _player = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithAsset:asset]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_playReachedEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    
    __unsafe_unretained SCViewController *mySelf = self;
    _observer = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 60) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        mySelf.scrollableWaveformView.waveformView.progressTime = time;
    }];
}

- (void)_playReachedEnd:(NSNotification *)notification {
    if (notification.object == _player.currentItem) {
        [_player seekToTime:kCMTimeZero];
        [_player play];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player removeTimeObserver:_observer];
}

- (IBAction)precisionChanged:(UISlider *)sender {
    self.scrollableWaveformView.waveformView.precision = sender.value;
}
- (IBAction)lineWidthChanged:(UISlider *)sender {
    self.scrollableWaveformView.waveformView.lineWidthRatio = sender.value;
}

- (IBAction)playButtonTapped:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        [_player play];
    } else {
        [_player pause];
    }
}

- (IBAction)changeColorsTapped:(id)sender {
    CGFloat hue = ((CGFloat)arc4random_uniform(10000)) / 10000.0;
    self.scrollableWaveformView.waveformView.progressColor = [UIColor colorWithHue:hue saturation:1 brightness:1 alpha:1];
    self.scrollableWaveformView.waveformView.normalColor = [UIColor colorWithHue:hue saturation:0.5 brightness:1 alpha:1];
}
- (IBAction)stereoSwitchChanged:(UISwitch *)sender {
    self.scrollableWaveformView.waveformView.channelEndIndex = sender.on ? 1 : 0;
//    self.scrollableWaveformView.waveformView.channelStartIndex = sender.on ? 1 : 0;
}

- (IBAction)sliderProgressChanged:(UISlider*)sender
{
    CMTime start = self.scrollableWaveformView.waveformView.timeRange.start;
    CMTime duration = CMTimeMakeWithSeconds(
                                            sender.value * CMTimeGetSeconds(self.scrollableWaveformView.waveformView.asset.duration),
                                            100000);
    
    // Adjusting the start time
    if (CMTIME_COMPARE_INLINE(CMTimeAdd(start, duration), >, self.scrollableWaveformView.waveformView.asset.duration)) {
        start = CMTimeSubtract(self.scrollableWaveformView.waveformView.asset.duration, duration);
    }
    
    self.scrollableWaveformView.waveformView.timeRange = CMTimeRangeMake(start, duration);
}

@end
