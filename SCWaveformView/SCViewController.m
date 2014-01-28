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

    self.waveformView.normalColor = [UIColor blueColor];
    self.waveformView.progressColor = [UIColor redColor];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"test" withExtension:@"m4a"] options:nil];
    
    self.waveformView.asset = asset;
    self.waveformView.progress = 0.5;
    
    [self.waveformView generateWaveforms];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)sliderProgressChanged:(UISlider*)sender
{
    self.waveformView.progress = sender.value;
}

@end
