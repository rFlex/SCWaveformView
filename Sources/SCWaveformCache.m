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
    NSMutableData *_cachedData;
    CMTime _actualAssetDuration;
    BOOL _readEndOfAsset;
    BOOL _readStartOfAsset;
}

@end

@implementation SCWaveformCache

- (void)invalidate {
//    NSLog(@"-- INVALIDATING CACHE --");
    _samplesPerPixel = 0;
    _cachedStartTime = kCMTimeInvalid;
    _cachedData = [NSMutableData new];
    _readEndOfAsset = NO;
    _readStartOfAsset = NO;
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

- (CMTime)cacheDuration {
    return CMTimeMultiply(_timePerPixel, (int)(_cachedData.length / sizeof(float)));
}

- (BOOL)readTimeRange:(CMTimeRange)timeRange width:(CGFloat)width error:(NSError *__autoreleasing *)error {
    if (self.asset == nil) {
        return NO;
    }
    
    if (CMTIME_COMPARE_INLINE(timeRange.start, <, kCMTimeZero)) {
        timeRange.start = kCMTimeZero;
    }
    
    CMTime assetDuration = [self actualAssetDuration];
    if (CMTIME_IS_POSITIVE_INFINITY(timeRange.duration)) {
        timeRange.duration = assetDuration;
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
    
    timeRange.duration = CMTimeConvertScale(timeRange.duration, sampleRate, kCMTimeRoundingMethod_Default);
    UInt64 totalSamples = timeRange.duration.value;
    
    NSUInteger samplesPerPixel = totalSamples / width;
    samplesPerPixel = samplesPerPixel < 1 ? 1 : samplesPerPixel;
    
    CMTimeRange oldTimeRange = timeRange;
    
    timeRange.start.value = timeRange.start.value - timeRange.start.value % samplesPerPixel;
    timeRange.duration.value = timeRange.duration.value - timeRange.duration.value % samplesPerPixel;
    
    _timePerPixel = CMTimeMultiplyByRatio(timeRange.duration, 1, width);
    
    CMTime cacheDuration = [self cacheDuration];
    CMTime cacheEndTime = CMTimeAdd(_cachedStartTime, cacheDuration);
    
    while (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), <, CMTimeAdd(oldTimeRange.start, oldTimeRange.duration))) {
        timeRange.duration.value += samplesPerPixel;
    }
    timeRange.duration.value += samplesPerPixel;
    
    if (samplesPerPixel != _samplesPerPixel ||
        CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), <, _cachedStartTime) || CMTIME_COMPARE_INLINE(timeRange.start, >, cacheEndTime)) {
        [self invalidate];
        cacheDuration = kCMTimeZero;
        cacheEndTime = kCMTimeInvalid;
    }
    
    BOOL shouldReadAsset = !(_readStartOfAsset && _readEndOfAsset);
    BOOL shouldAppendPageAtBeginning = YES;
    BOOL shouldSetStartTime = NO;
    BOOL isLastSegment = NO;

    if (shouldReadAsset) {
        if (CMTIME_IS_VALID(_cachedStartTime)) {
            if (CMTIME_COMPARE_INLINE(timeRange.start, <, _cachedStartTime)) {
                timeRange.start = CMTimeSubtract(_cachedStartTime, timeRange.duration);
                
                if (CMTIME_COMPARE_INLINE(timeRange.start, <, kCMTimeZero)) {
                    timeRange.start = kCMTimeZero;
                }
                
                if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), >, _cachedStartTime)) {
                    timeRange.duration = CMTimeSubtract(_cachedStartTime, timeRange.start);
                }
                
                shouldSetStartTime = YES;
            } else {
                if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), >, cacheEndTime)) {
                    timeRange.start = cacheEndTime;
                    
                    shouldAppendPageAtBeginning = NO;
                } else {
                    shouldReadAsset = NO;
                }
            }
        } else {
            shouldSetStartTime = YES;
        }

        if (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), >, assetDuration)) {
            if (shouldReadAsset) {
                shouldReadAsset = !_readEndOfAsset;
            }
            isLastSegment = YES;
        }
    }
    
    if (shouldReadAsset) {
        BOOL isFirstSegment = CMTIME_COMPARE_INLINE(timeRange.start, ==, kCMTimeZero);
        
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
        
        reader.timeRange = timeRange;
        
        [reader addOutput:output];
        
        [reader startReading];
        
        double bigSample = 0;
        NSUInteger bigSampleCount = 0;
        NSMutableData *data = [NSMutableData new];
        UInt32 bytesPerInputSample = 2 * channelCount;
        CMTime beginTime = kCMTimeInvalid;
        long long sampleRead = 0;
        NSUInteger maxDataLength = sizeof(float) * ceil(CMTimeGetSeconds(timeRange.duration) / CMTimeGetSeconds(_timePerPixel));
        BOOL reachedStart = NO;
        
        while (reader.status == AVAssetReaderStatusReading) {
            CMSampleBufferRef sampleBufferRef = [output copyNextSampleBuffer];
            
            if (sampleBufferRef) {
                CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
                CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBufferRef);
                
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
                    
                    if (reachedStart || CMTIME_COMPARE_INLINE(time, >=, timeRange.start)) {
                        if (CMTIME_IS_INVALID(beginTime)) {
                            beginTime = time;
                        }
                        
                        sampleRead++;
                        
                        bigSample += sample;
                        bigSampleCount++;
                        
                        if (bigSampleCount == samplesPerPixel) {
                            float averageSample = (float)(bigSample / (double)bigSampleCount);
                            
                            bigSample = 0;
                            bigSampleCount = 0;
                            
                            if (data.length + sizeof(float) <= maxDataLength) {
                                [data appendBytes:&averageSample length:sizeof(float)];
                            } else {
                                break;
                            }
                        }
                    }
                    time.value++;
                }
                CFRelease(sampleBufferRef);
            }
        }
        
        if (bigSampleCount != 0 && isLastSegment) {
            float averageSample = bigSample / (float)bigSampleCount;

            [data appendBytes:&averageSample length:sizeof(float)];
        }
//        NSLog(@"Read %lld samples and generated %d cache entries (timePerPixel: %fs, samplesPerPixel: %d)", sampleRead, (int)(data.length / sizeof(float)), CMTimeGetSeconds(_timePerPixel), (int)samplesPerPixel);
//        NSLog(@"Duration requested: %fs, actual got: %fs", CMTimeGetSeconds(timeRange.duration), CMTimeGetSeconds(CMTimeMultiply(_timePerPixel, (int)(data.length / sizeof(float)))));

        if (shouldAppendPageAtBeginning) {
            [data appendData:_cachedData];
            _cachedData = data;
        } else {
            [_cachedData appendData:data];
        }
        
        if (shouldSetStartTime) {
            if (CMTIME_IS_VALID(beginTime)) {
                _cachedStartTime = beginTime;
            } else {
                _cachedStartTime = timeRange.start;
            }
        }
        _samplesPerPixel = samplesPerPixel;
        
        if (isLastSegment) {
            _readEndOfAsset = YES;
            _actualAssetDuration = CMTimeAdd(_cachedStartTime, CMTimeMultiply(_timePerPixel, (int)(_cachedData.length / sizeof(float))));
        }
        if (isFirstSegment) {
            _readStartOfAsset = YES;
            
            if (_readEndOfAsset) {
                _actualAssetDuration = CMTimeMultiply(_timePerPixel, (int)(_cachedData.length / sizeof(float)));
            }
        }
        
//        NSLog(@"Read timeRange %fs to %fs. New cache duration: %fs (end bounds: %fs), asset duration :%fs", CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration)),
//              CMTimeGetSeconds([self cacheDuration]), CMTimeGetSeconds(CMTimeAdd(_cachedStartTime, [self cacheDuration])), CMTimeGetSeconds([self actualAssetDuration]));
    }
    
    
    return YES;
}

- (void)readRange:(NSRange)range atTime:(CMTime)time handler:(SCAudioBufferHandler)handler {
    int indexAtStart = floor(CMTimeGetSeconds(CMTimeSubtract(time, _cachedStartTime)) / CMTimeGetSeconds(_timePerPixel));
    
    float *samples = _cachedData.mutableBytes;
    
    for (int x = (int)range.location, length = (int)(range.location + range.length); x < length; x++) {
        int idx = indexAtStart + x;
        float sample = -INFINITY;
        
        if (idx >= 0 && idx * sizeof(float) < _cachedData.length) {
            sample = samples[idx];
        } else if (idx * sizeof(float) >= _cachedData.length) {
//            NSLog(@"Out of bounds");
        }
        
        handler(x, sample, CMTimeAdd(_cachedStartTime, CMTimeMultiplyByFloat64(_timePerPixel, idx)));
    }
}

@end
