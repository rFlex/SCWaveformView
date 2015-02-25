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

@interface SCWaveformCache() {
    NSUInteger _samplesPerPixel;
    CMTime _cachedStartTime;
    CMTime _cachedEndTime;
    NSMutableData *_cachedData;
}

@end

@implementation SCWaveformCache

- (void)invalidate {
//    NSLog(@"-- INVALIDATING CACHE --");
    _samplesPerPixel = 0;
    _cachedStartTime = kCMTimeInvalid;
    _cachedEndTime = kCMTimeInvalid;
    _cachedData = [NSMutableData new];
}

- (void)setAsset:(AVAsset *)asset {
    [self willChangeValueForKey:@"asset"];
    
    _asset = asset;
    
    [self invalidate];
    
    [self didChangeValueForKey:@"asset"];
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
    
    CMTimeRange timeRangeToRead = timeRange;
    if (CMTIME_COMPARE_INLINE(timeRangeToRead.start, <, kCMTimeZero)) {
        timeRangeToRead.start = kCMTimeZero;
    }
    if (CMTIME_IS_POSITIVE_INFINITY(timeRangeToRead.duration)) {
        timeRangeToRead.duration = self.asset.duration;
    }
    
    NSArray *audioTrackArray = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (audioTrackArray.count == 0) {
        return [SCWaveformCache applyError:error withMessage:@"No audio track in asset"];
    }
    
    AVAssetTrack *songTrack = [audioTrackArray objectAtIndex:0];

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
    
    timeRangeToRead.duration = CMTimeConvertScale(timeRangeToRead.duration, sampleRate, kCMTimeRoundingMethod_Default);
    UInt64 totalSamples = timeRangeToRead.duration.value;
    
    NSUInteger samplesPerPixel = totalSamples / width;
    samplesPerPixel = samplesPerPixel < 1 ? 1 : samplesPerPixel;
    CMTime timePerPixel = CMTimeMultiplyByRatio(timeRangeToRead.duration, 1, samplesPerPixel);
//    CMTime timePerPixel = CMTimeMake(timeRangeToRead.duration.value, timeRangeToRead.duration.timescale / samplesPerPixel);
    
    if (samplesPerPixel != _samplesPerPixel ||
        CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), <, _cachedStartTime) ||
        CMTIME_COMPARE_INLINE(timeRangeToRead.start, >, _cachedEndTime)) {
//        NSLog(@"CachedStartTime: %fs, CachedEndTime: %fs, Start: %fs, End: %fs, Duration: %fs", CMTimeGetSeconds(_cachedStartTime), CMTimeGetSeconds(_cachedEndTime), CMTimeGetSeconds(timeRangeToRead.start),
//              CMTimeGetSeconds(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration)),
//              CMTimeGetSeconds(timeRangeToRead.duration));
        [self invalidate];
    }
    
    CMTime newCacheStartTime = timeRangeToRead.start;
    CMTime newCacheEndTime = CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration);
    
    BOOL shouldReadAsset = YES;
    BOOL shouldAppendPageAtBeginning = YES;
    
    if (CMTIME_IS_VALID(_cachedStartTime)) {
        if (CMTIME_COMPARE_INLINE(timeRangeToRead.start, <, _cachedStartTime)) {
            timeRangeToRead.start = CMTimeSubtract(_cachedStartTime, timeRangeToRead.duration);
            
            if (CMTIME_COMPARE_INLINE(timeRangeToRead.start, <, kCMTimeZero)) {
                timeRangeToRead.start = kCMTimeZero;
            }
            
            if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), >, _cachedStartTime)) {
                timeRangeToRead.duration = CMTimeSubtract(_cachedStartTime, timeRangeToRead.start);
            }
            
            newCacheStartTime = timeRangeToRead.start;
            newCacheEndTime = _cachedEndTime;
        } else {
            if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), >, _cachedEndTime)) {
                timeRangeToRead.start = _cachedEndTime;
                newCacheStartTime = _cachedStartTime;
                newCacheEndTime = CMTimeAdd(_cachedEndTime, timeRangeToRead.duration);
                
                shouldAppendPageAtBeginning = NO;
            } else {
                shouldReadAsset = NO;
            }
        }
    }
    
    if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), >, self.asset.duration)) {
        CMTime adjustedDuration = CMTimeSubtract(self.asset.duration, timeRangeToRead.start);
        newCacheEndTime = self.asset.duration;
        timeRangeToRead.duration = adjustedDuration;
        
        if (shouldReadAsset && CMTIME_IS_VALID(_cachedEndTime) && CMTIME_COMPARE_INLINE(_cachedEndTime, >=, newCacheEndTime)) {
            shouldReadAsset = NO;
        }
    }
    
    if (shouldReadAsset) {
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
        
        reader.timeRange = timeRangeToRead;
        
        [reader addOutput:output];
        
        [reader startReading];
        
        double bigSample = 0;
        NSUInteger bigSampleCount = 0;
        NSMutableData *data = [NSMutableData new];
        UInt32 bytesPerInputSample = 2 * channelCount;

        CGFloat currentX = 0;
        while (reader.status == AVAssetReaderStatusReading) {
            CMSampleBufferRef sampleBufferRef = [output copyNextSampleBuffer];
            
            if (sampleBufferRef) {
                CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
                size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
       
                char *dataPointer;
                CMBlockBufferGetDataPointer(blockBufferRef, 0, &bufferLength, nil, &dataPointer);
                
                SInt16 *samples = (SInt16 *)dataPointer;
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
                        float averageSample = bigSample / (float)bigSampleCount;
                        
                        [data appendBytes:&averageSample length:(sizeof(float))];
                        
                        currentX++;
                        bigSample = 0;
                        bigSampleCount  = 0;
                    }
                }
                CMSampleBufferInvalidate(sampleBufferRef);
                CFRelease(sampleBufferRef);
            }
        }
        
//        // Rendering the last pixel
//        bigSample = bigSampleCount > 0 ? bigSample / (double)bigSampleCount : noiseFloor;
//        if (currentX < width) {
//            handler(currentX, bigSample);
//        }
        
        if (shouldAppendPageAtBeginning) {
            [data appendData:_cachedData];
            _cachedData = data;
        } else {
            [_cachedData appendData:data];
        }
        
        _cachedStartTime = newCacheStartTime;
        _cachedEndTime = newCacheEndTime;
        _samplesPerPixel = samplesPerPixel;
        
//        NSLog(@"Read timeRange %fs with duration %fs. New cache length: %u (%fs from %fs)", CMTimeGetSeconds(timeRangeToRead.start), CMTimeGetSeconds(timeRangeToRead.duration), (uint)_cachedData.length, CMTimeGetSeconds(_cachedStartTime), CMTimeGetSeconds(_cachedEndTime));
    }
    
    float indexRatio = (CMTimeGetSeconds(timeRange.start) - CMTimeGetSeconds(_cachedStartTime)) / CMTimeGetSeconds(CMTimeSubtract(_cachedEndTime, _cachedStartTime));
    
    int indexAtStart = ((_cachedData.length / sizeof(float)) * indexRatio);
//    NSLog(@"At %fs (%fs from %fs) -> %f", CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(_cachedStartTime), CMTimeGetSeconds(_cachedEndTime), indexRatio);

    float *samples = _cachedData.mutableBytes;
    CMTime currentTime = timeRange.start;
    
    for (int x = 0; x < width; x++) {
        int idx = indexAtStart + x;
        
        if (idx >= 0) {
            if (idx * sizeof(float) >= _cachedData.length) {
                break;
            }
            handler(x, samples[idx], currentTime);
        }
        currentTime = CMTimeAdd(currentTime, timePerPixel);
    }
    

    return YES;
}

@end
