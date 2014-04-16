//
//  SCViewController.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/01/14.
//  Copyright (c) 2014 Simon CORSIN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCWaveformView.h"

@interface SCViewController : UIViewController

@property (weak, nonatomic) IBOutlet SCWaveformView *waveformView;
- (IBAction)changeColorsTapped:(id)sender;
- (IBAction)sliderProgressChanged:(id)sender;

@end
