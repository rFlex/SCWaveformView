//
//  SCScrollableWaveformView.h
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCWaveformView.h"

@interface SCScrollableWaveformView : UIScrollView<UIScrollViewDelegate>

@property (readonly, nonatomic) SCWaveformView *waveformView;

@end
