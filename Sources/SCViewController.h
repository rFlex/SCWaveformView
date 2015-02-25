//
//  SCViewController.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCWaveformView.h"
#import "SCScrollableWaveformView.h"

@interface SCViewController : UIViewController

@property (weak, nonatomic) IBOutlet SCScrollableWaveformView *scrollableWaveformView;
@property (weak, nonatomic) IBOutlet UISlider *slider;
- (IBAction)playButtonTapped:(UIButton *)sender;

- (IBAction)changeColorsTapped:(id)sender;
- (IBAction)sliderProgressChanged:(id)sender;

@end
