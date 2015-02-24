//
//  SCWaveformCache.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import "SCWaveformCache.h"
#define absX(x) (x < 0 ? 0 - x : x)
#define minMaxX(x, mn, mx) (x <= mn ? mn : (x >= mx ? mx : x))
#define noiseFloor (-50.0)
#define decibel(amplitude) (20.0 * log10(absX(amplitude) / 32767.0))

@implementation SCWaveformCache

- (void)invalidate {
    
}

- (void)setAsset:(AVAsset *)asset {
    _asset = asset;
    
    [self invalidate];
}

+ (BOOL)applyError:(NSError **)error withMessage:(NSString *)message {
    if (error != nil) {
        *error = [NSError errorWithDomain:@"SCWaveformView" code:500 userInfo:@{
                                                                                NSLocalizedDescriptionKey : message
                                                                                }];
    }
    
    return NO;
}

- (BOOL)readTimeRange:(CMTimeRange)timeRange width:(CGFloat)width error:(NSError **)error handler:(SCAudioBufferHandler)handler {
    if (self.asset == nil) {
        return NO;
    }
    
    NSArray *audioTrackArray = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (audioTrackArray.count == 0) {
        return [SCWaveformCache applyError:error withMessage:@"No audio track in asset"];
    }
    
    AVAssetTrack *songTrack = [audioTrackArray objectAtIndex:0];
    
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                        [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                        nil];
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:self.asset error:error];
    
    if (reader == nil) {
        return NO;
    }
    
    reader.timeRange = timeRange;
    
    [reader addOutput:output];

    UInt32 channelCount;
    NSArray *formatDesc = songTrack.formatDescriptions;
    UInt32 sampleRate = 0;
    for (unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        
        if (fmtDesc == nil) {
            return [SCWaveformCache applyError:error withMessage:@"Unable to get audio stream description"];
        }
        
        channelCount = fmtDesc->mChannelsPerFrame;
        sampleRate = (UInt32)fmtDesc->mSampleRate;
    }
    
    
    UInt32 bytesPerInputSample = 2 * channelCount;
    UInt64 totalSamples = 0;
    CMTime duration;
    
    if (CMTIME_IS_POSITIVE_INFINITY(timeRange.duration)) {
        duration = self.asset.duration;
    } else {
        duration = timeRange.duration;
    }
    
    duration = CMTimeConvertScale(duration, sampleRate, kCMTimeRoundingMethod_Default);
    totalSamples = duration.value;
    
    NSUInteger samplesPerPixel = totalSamples / width;
    samplesPerPixel = samplesPerPixel < 1 ? 1 : samplesPerPixel;
    [reader startReading];
    
    double bigSample = 0;
    NSUInteger bigSampleCount = 0;
    NSMutableData * data = [NSMutableData dataWithLength:32768];
    
    CGFloat currentX = 0;
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBufferRef = [output copyNextSampleBuffer];
        
        if (sampleBufferRef) {
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
            
            if (data.length < bufferLength) {
                [data setLength:bufferLength];
            }
            
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data.mutableBytes);
            
            SInt16 *samples = (SInt16 *)data.mutableBytes;
            int sampleCount = (int)(bufferLength / bytesPerInputSample);
            for (int i = 0; i < sampleCount; i++) {
                Float32 sample = (Float32) *samples++;
                sample = decibel(sample);
                sample = minMaxX(sample, noiseFloor, 0);
                
                for (int j = 1; j < channelCount; j++) {
                    samples++;
                }
                
                bigSample += sample;
                bigSampleCount++;
                
                if (bigSampleCount == samplesPerPixel) {
                    double averageSample = bigSample / (double)bigSampleCount;
                    
                    handler(currentX, averageSample);
                    
                    currentX++;
                    bigSample = 0;
                    bigSampleCount  = 0;
                }
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
        }
    }
    
    // Rendering the last pixel
    bigSample = bigSampleCount > 0 ? bigSample / (double)bigSampleCount : noiseFloor;
    if (currentX < width) {
        handler(currentX, bigSample);
    }
    
    return YES;
}

@end
