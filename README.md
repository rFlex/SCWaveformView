SCWaveformView
==============

A blazing fast customizable waveform view. Extract the audio section of an asset (which can be both video or audio) and display a waveform.

The SCWaveformView is optimized to do the less file read possible. When scrolling or displaying another part of the waveform, it will only read whatever it needs to render the new section. It will cache the file data to avoid having to read sections that have been already computed. Furthermore, if it does have to read the file, it will read it by bigger segment to minimize the number of read operations next time the timeRange changes.

Main features:
  * Can show a play progress.
  * Colors are changeable at runtime without reprocessing the asset.
  * Doesn't have to read the whole file if you display only a portion of your audio on screen.
  * Features a scrollable waveform view..
  * Can set a precision to make the drawing faster on some devices
  * LineWidth is changeable so you can have a unique waveform design
  * Set the asset, then you are good to go.
  * ARC.

<img src="http://i.imgur.com/dVGhYBk.png" width=500>

This project is inspired from https://github.com/fulldecent/FDWaveformView

Podfile
----------------

If you are using cocoapods, you can use this project with the following Podfile

    platform :ios, '7.0'
    pod "SCWaveformView"

Example
-------

     // Allocating the waveformview
     SCWaveformView *waveformView = [[SCWaveformView alloc] init];
     
     // Setting the asset
     AVAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:@"blabla.mp3"]];
     waveformView.asset = asset;
     
     // Setting the waveform colors
     waveformView.normalColor = [UIColor greenColor];
     waveformView.progressColor = [UIColor redColor];
     
     // Set the play progress
     waveformView.progressTime = CMTimeMakeWithSeconds(5, 10000);
     
     // Show only the first second of your asset
     waveformView.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(1, 1));
     
     // Use it inside a scrollView
     SCScrollableWaveformView *scrollableWaveformView = [SCScrollableWaveformView new];
     scrollableWaveformView.waveformView; // Access the waveformView from there
     
     // Set the precision, 1 being the maximum
     waveformView.precision = 0.25; // We are going to render one line per four pixels
     
     // Set the lineWidth so we have some space between the lines
     waveformView.lineWidthRatio = 0.5;
     
