SCWaveformView
==============

A blazing fast customizable waveform view. Extract the audio section of an asset (which can be both video or audio) and display a waveform. Compared to other libs that are found on the web, this one does not do much memory allocations. Only one pass is also done to create the waveform.

Main features:
  * Can show a play progress
  * Colors are changeable at runtime without reprocessing the asset
  * Generated waveforms are retrievable
  * Set the asset, then you are good to go
  * ARC

<img src="http://i.imgur.com/dVGhYBk.png" width=500>

This project is inspired from https://github.com/fulldecent/FDWaveformView

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
     waveformView.progress = 0.4;
     
     // Even though the waveformview will eventually reprocess the waveforms when needed
     // You can ask it to generate the waveforms right now
     [waveformView generateWaveforms];
     
     // Retrieve the waveforms. for whatever reasons
     UIImage *progressWaveformImage = waveformView.generatedProgressImage;
     UIImage *normalWaveformImage = waveformView.generatedNormalImage;
     
