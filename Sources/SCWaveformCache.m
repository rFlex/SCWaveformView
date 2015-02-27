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
//    CMTime _cachedEndTime;
    NSMutableData *_cachedData;
    CMTime _actualAssetDuration;
    BOOL _readEndOfAsset;
}

@end

@implementation SCWaveformCache

- (void)invalidate {
//    NSLog(@"-- INVALIDATING CACHE --");
    _samplesPerPixel = 0;
    _cachedStartTime = kCMTimeInvalid;
//    _cachedEndTime = kCMTimeInvalid;
    _cachedData = [NSMutableData new];
    _readEndOfAsset = NO;
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

- (CMTime)actualAssetDuration {
    if (_readEndOfAsset) {
        return _actualAssetDuration;
    }
    
    return _asset.duration;
}

- (BOOL)readTimeRange:(CMTimeRange)timeRange width:(CGFloat)width error:(NSError *__autoreleasing *)error {
    if (self.asset == nil) {
        return NO;
    }
    
    CMTimeRange timeRangeToRead = timeRange;
    if (CMTIME_COMPARE_INLINE(timeRangeToRead.start, <, kCMTimeZero)) {
        timeRangeToRead.start = kCMTimeZero;
    }
    
    CMTime assetDuration = [self actualAssetDuration];
    if (CMTIME_IS_POSITIVE_INFINITY(timeRangeToRead.duration)) {
        timeRangeToRead.duration = assetDuration;
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
    _timePerPixel = CMTimeMultiplyByRatio(timeRangeToRead.duration, 1, width);
    
    CMTime cacheDuration = CMTimeMultiply(_timePerPixel, _cachedData.length / sizeof(float));
    CMTime cacheEndTime = CMTimeAdd(_cachedStartTime, cacheDuration);
    
    if (samplesPerPixel != _samplesPerPixel ||
        CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), <, _cachedStartTime) || CMTIME_COMPARE_INLINE(timeRangeToRead.start, >, cacheEndTime)) {
        [self invalidate];
        cacheDuration = kCMTimeZero;
        cacheEndTime = kCMTimeInvalid;
        
    }
    timeRangeToRead.duration.value = timeRangeToRead.duration.value - timeRangeToRead.duration.value % samplesPerPixel + samplesPerPixel;
    
    CMTime newCacheStartTime = timeRangeToRead.start;
    
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
        } else {
            if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), >, cacheEndTime)) {
                timeRangeToRead.start = cacheEndTime;
                newCacheStartTime = _cachedStartTime;
                
                shouldAppendPageAtBeginning = NO;
            } else {
                shouldReadAsset = NO;
            }
        }
    }
    
    BOOL isLastSegment = NO;
    
    if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRangeToRead.start, timeRangeToRead.duration), >, assetDuration)) {
        if (shouldReadAsset) {
            shouldReadAsset = !_readEndOfAsset;
        }
        isLastSegment = YES;
    }
    
    if (shouldReadAsset) {
        NSDictionary *outputSettingsDict = @{
                                             AVFormatIDKey : [NSNumber numberWithInt:kAudioFormatLinearPCM],
                                             AVLinearPCMBitDepthKey : @16,
                                             AVLinearPCMIsBigEndianKey : @NO,
                                             AVLinearPCMIsFloatKey : @NO,
                                             AVLinearPCMIsNonInterleaved : @NO
                                             };
        
        AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
        output.alwaysCopiesSampleData = NO;
        
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
                        
                        bigSample = 0;
                        bigSampleCount  = 0;
                    }
                }
                CFRelease(sampleBufferRef);
            }
        }
        
        if (bigSampleCount != 0 && isLastSegment) {
            float averageSample = bigSample / (float)bigSampleCount;

            [data appendBytes:&averageSample length:sizeof(float)];
        }
        
        if (shouldAppendPageAtBeginning) {
            [data appendData:_cachedData];
            _cachedData = data;
        } else {
            [_cachedData appendData:data];
        }
        
        _cachedStartTime = newCacheStartTime;
        _samplesPerPixel = samplesPerPixel;
        
        if (isLastSegment) {
            _readEndOfAsset = YES;
            _actualAssetDuration = CMTimeAdd(_cachedStartTime, CMTimeMultiply(_timePerPixel, _cachedData.length / sizeof(float)));
        }
        
        NSLog(@"Read timeRange %fs with duration %fs. New cache duration: %fs (end bounds: %fs)", CMTimeGetSeconds(timeRangeToRead.start), CMTimeGetSeconds(timeRangeToRead.duration),
              CMTimeGetSeconds(CMTimeMultiply(_timePerPixel, _cachedData.length / sizeof(float))), CMTimeGetSeconds(CMTimeAdd(_cachedStartTime, CMTimeMultiply(_timePerPixel, _cachedData.length / sizeof(float)))));
    }
    
    
    return YES;
}

- (void)readRange:(NSRange)range atTime:(CMTime)time handler:(SCAudioBufferHandler)handler {
    int indexAtStart = ceil(CMTimeGetSeconds(CMTimeSubtract(time, _cachedStartTime)) / CMTimeGetSeconds(_timePerPixel));
    
    float *samples = _cachedData.mutableBytes;
    
    for (int x = range.location, length = range.location + range.length; x < length; x++) {
        int idx = indexAtStart + x;
        float sample = -INFINITY;
        
        if (idx >= 0 && idx * sizeof(float) < _cachedData.length) {
            sample = samples[idx];
        }
        
        handler(x, sample, CMTimeAdd(_cachedStartTime, CMTimeMultiplyByFloat64(_timePerPixel, idx)));
    }
}

@end
