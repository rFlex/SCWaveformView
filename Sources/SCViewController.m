//
//  SCViewController.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import "SCViewController.h"
#import "SCWaveformView.h"

@interface SCViewController ()

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.waveformView.normalColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1];
    self.waveformView.progressColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"test" withExtension:@"m4a"] options:nil];
    self.waveformView.alpha = 0.8;
    
    self.waveformView.asset = asset;
    self.waveformView.progress = 0.5;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)changeColorsTapped:(id)sender {
    CGFloat hue = ((CGFloat)arc4random_uniform(10000)) / 10000.0;
    self.waveformView.progressColor = [UIColor colorWithHue:hue saturation:1 brightness:1 alpha:1];
    self.waveformView.normalColor = [UIColor colorWithHue:hue saturation:0.5 brightness:1 alpha:1];
}

- (IBAction)sliderProgressChanged:(UISlider*)sender
{
    self.waveformView.progress = sender.value;
}

@end
