//
//  SCWaveformCache.m
//  SCWaveformView
//
//  Created by Simon CORSIN on 24/02/15.
//  Copyright (c) 2015 Simon CORSIN. All rights reserved.
//

#import "SCWaveformCache.h"

#ifndef SCWaveformDebug
# define SCWaveformDebug 0
#endif

@interface SCWaveformCache() {
    NSUInteger _samplesPerPixel;
    CMTime _cachedStartTime;
    NSMutableArray *_channelsCachedData;
    CMTime _actualAssetDuration;
    BOOL _readEndOfAsset;
    BOOL _readStartOfAsset;
}

@end

@implementation SCWaveformCache

- (id)init {
    self = [super init];
    
    if (self) {
        _maxChannels = 1;
    }
    
    return self;
}

- (void)invalidate {
#if SCWaveformDebug
    NSLog(@"invalidate waveform cache");
#endif

    _samplesPerPixel = 0;
    _cachedStartTime = kCMTimeInvalid;
    _channelsCachedData = [NSMutableArray new];
    
    for (NSUInteger i = 0; i < _maxChannels; i++) {
        [_channelsCachedData addObject:[NSMutableData new]];
    }
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
    if (_channelsCachedData.count == 0) {
        return kCMTimeZero;
    }
    NSData *cachedData = _channelsCachedData.firstObject;
    return CMTimeMultiply(_timePerPixel, (int)(cachedData.length / sizeof(float)));
}

static float SCDecibelAverage(double sample, NSUInteger sampleCount) {
    return 20.0 * log10(sample / (double)sampleCount);
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
    
    UInt32 channelCount = 1;
    NSArray *formatDesc = songTrack.formatDescriptions;
    UInt32 sampleRate = 0;
    for (NSUInteger i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        
        if (fmtDesc == nil) {
            return [SCWaveformCache applyError:error withMessage:@"Unable to get audio stream description"];
        }
        
        channelCount = fmtDesc->mChannelsPerFrame;
        sampleRate = (UInt32)fmtDesc->mSampleRate;
    }
    
    if (channelCount > _maxChannels) {
        channelCount = (int)_maxChannels;
    }
    
    timeRange.duration = CMTimeConvertScale(timeRange.duration, sampleRate, kCMTimeRoundingMethod_Default);
    UInt64 totalSamples = timeRange.duration.value;
    
    NSUInteger samplesPerPixel = roundf((CGFloat)totalSamples / (CGFloat)width);
    samplesPerPixel = samplesPerPixel < 1 ? 1 : samplesPerPixel;
    
    CMTimeRange oldTimeRange = timeRange;
    
    timeRange.start.value = timeRange.start.value - timeRange.start.value % samplesPerPixel;
    timeRange.duration.value = timeRange.duration.value - timeRange.duration.value % samplesPerPixel;
    
    _timePerPixel = CMTimeMultiplyByFloat64(timeRange.duration, 1 / width);
    
    CMTime cacheDuration = [self cacheDuration];
    CMTime cacheEndTime = CMTimeAdd(_cachedStartTime, cacheDuration);
    
    while (CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), <, CMTimeAdd(oldTimeRange.start, oldTimeRange.duration))) {
        timeRange.duration.value += samplesPerPixel;
    }
    timeRange.duration.value += samplesPerPixel;
    
    if (samplesPerPixel != _samplesPerPixel ||
        CMTIME_COMPARE_INLINE(CMTimeAdd(timeRange.start, timeRange.duration), <, _cachedStartTime) || CMTIME_COMPARE_INLINE(timeRange.start, >, cacheEndTime)) {
        [self invalidate];
        cacheEndTime = kCMTimeInvalid;
    }
    
    while (channelCount < [self actualNumberOfChannels]) {
        [_channelsCachedData removeLastObject];
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
                                             AVLinearPCMBitDepthKey : @32,
                                             AVLinearPCMIsBigEndianKey : @NO,
                                             AVLinearPCMIsFloatKey : @YES,
                                             AVLinearPCMIsNonInterleaved : @NO,
                                             AVNumberOfChannelsKey : [NSNumber numberWithUnsignedInteger:channelCount]
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
        
        NSUInteger addedSampleCount = 0;
        NSMutableArray *channelsData = [NSMutableArray new];
        
        for (NSUInteger i = 0; i < channelCount; i++) {
            [channelsData addObject:[NSMutableData new]];
        }
        
        CMTime beginTime = kCMTimeInvalid;
        long long sampleRead = 0;
        NSUInteger maxDataLength = sizeof(float) * ceil(CMTimeGetSeconds(timeRange.duration) / CMTimeGetSeconds(_timePerPixel));
        BOOL reachedStart = NO;
        
        double *addedSamples = malloc(sizeof(double) * channelCount);
        memset(addedSamples, 0, sizeof(double) * channelCount);

#if SCWaveformDebug
        CFTimeInterval start = CACurrentMediaTime();
        CFTimeInterval timeTakenCopy = 0;
        CFTimeInterval timeTakenProcessing = 0;
#endif
        
        while (reader.status == AVAssetReaderStatusReading) {
#if SCWaveformDebug
            CFTimeInterval copy = CACurrentMediaTime();
#endif
            CMSampleBufferRef sampleBufferRef = [output copyNextSampleBuffer];
#if SCWaveformDebug
            timeTakenCopy += (CACurrentMediaTime() - copy);
#endif
            
            if (sampleBufferRef) {
#if SCWaveformDebug
                copy = CACurrentMediaTime();
#endif
                
                CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
                CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBufferRef);
                
                size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
                
                char *dataPointer;
                CMBlockBufferGetDataPointer(blockBufferRef, 0, &bufferLength, nil, &dataPointer);
                
                Float32 *samples = (Float32 *)dataPointer;
                int sampleCount = (int)(bufferLength / sizeof(Float32));
                int currentChannel = 0;
                Float32 sample = 0;
                
                for (NSUInteger i = 0; i < sampleCount; i++) {
                    sample = *samples;
                    
                    BOOL isLastChannel = currentChannel + 1 == channelCount;

                    if (reachedStart || CMTIME_COMPARE_INLINE(time, >=, timeRange.start)) {
                        reachedStart = YES;
                        
                        if (sample < 0) {
                            sample = -sample;
                        }
                        
                        if (CMTIME_IS_INVALID(beginTime)) {
                            beginTime = time;
                        }
                        
                        sampleRead++;
                        
                        addedSamples[currentChannel] += sample;
                        
                        if (currentChannel == 0) {
                            addedSampleCount++;
                        }
                       
                        if (addedSampleCount == samplesPerPixel) {
                            float averageSample = SCDecibelAverage(addedSamples[currentChannel], addedSampleCount);
                            
                            addedSamples[currentChannel] = 0;
                            
                            if (isLastChannel) {
                                addedSampleCount = 0;
                            }
                            
                            NSMutableData *data = [channelsData objectAtIndex:currentChannel];
                            
                            if (data.length + sizeof(float) <= maxDataLength) {
                                [data appendBytes:&averageSample length:sizeof(float)];
                            } else {
                                break;
                            }
                        }
                    }
                    
                    if (isLastChannel) {
                        time.value++;
                    }
                    
                    samples++;
                    currentChannel = (currentChannel + 1) % channelCount;
                }
                CFRelease(sampleBufferRef);

#if SCWaveformDebug
                timeTakenProcessing += (CACurrentMediaTime() - copy);
#endif
            }
        }
        
        if (addedSampleCount != 0 && isLastSegment) {
            for (NSUInteger i = 0; i < channelCount; i++) {
                float averageSample = SCDecibelAverage(addedSamples[i], addedSampleCount);
                NSMutableData *data = [channelsData objectAtIndex:i];

                [data appendBytes:&averageSample length:sizeof(float)];
            }
        }
        
        free(addedSamples);

#if SCWaveformDebug
        for (NSUInteger i = 0; i < channelCount; i++) {
            NSData *data = [channelsData objectAtIndex:i];
            NSLog(@"Read %lld samples and generated %d cache entries (timePerPixel: %fs, samplesPerPixel: %d)", sampleRead, (int)(data.length / sizeof(float)), CMTimeGetSeconds(_timePerPixel), (int)samplesPerPixel);
            NSLog(@"Duration requested: %fs, actual got: %fs", CMTimeGetSeconds(timeRange.duration), CMTimeGetSeconds(CMTimeMultiply(_timePerPixel, (int)(data.length / sizeof(float)))));
        }
#endif
        
        for (NSUInteger i = 0; i < channelCount; i++) {
            NSMutableData *data = [channelsData objectAtIndex:i];
            NSMutableData *cachedData = [_channelsCachedData objectAtIndex:i];
            
            if (shouldAppendPageAtBeginning) {
                [data appendData:cachedData];
                [_channelsCachedData setObject:data atIndexedSubscript:i];
            } else {
                [cachedData appendData:data];
            }
        }

#if SCWaveformDebug
        NSLog(@"Read file in %fs (copy: %fs, processing: %fs)", (float)(CACurrentMediaTime() - start), (float)timeTakenCopy, (float)timeTakenProcessing);
#endif
        
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
            _actualAssetDuration = CMTimeAdd(_cachedStartTime, [self cacheDuration]);
        }
        if (isFirstSegment) {
            _readStartOfAsset = YES;
            
            if (_readEndOfAsset) {
                _actualAssetDuration = [self cacheDuration];
            }
        }

#if SCWaveformDebug
        NSLog(@"Read timeRange %fs to %fs. New cache duration: %fs (end bounds: %fs), asset duration: %fs", CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration)),
              CMTimeGetSeconds([self cacheDuration]), CMTimeGetSeconds(CMTimeAdd(_cachedStartTime, [self cacheDuration])), CMTimeGetSeconds([self actualAssetDuration]));
#endif
    }
    
    
    return YES;
}

- (void)readRange:(NSRange)range atTime:(CMTime)time handler:(SCAudioBufferHandler)handler {
    int indexAtStart = floor(CMTimeGetSeconds(CMTimeSubtract(time, _cachedStartTime)) / CMTimeGetSeconds(_timePerPixel));
    
    for (int i = 0; i < _channelsCachedData.count; i++) {
        NSMutableData *data = [_channelsCachedData objectAtIndex:i];
        float *samples = data.mutableBytes;
        
        for (int x = (int)range.location, length = (int)(range.location + range.length); x < length; x++) {
            int idx = indexAtStart + x;
            float sample = -INFINITY;
            
            if (idx >= 0 && idx * sizeof(float) < data.length) {
                sample = samples[idx];
            }
    
            handler(i, x, sample, CMTimeAdd(_cachedStartTime, CMTimeMultiplyByFloat64(_timePerPixel, idx)));
        }
    }
}

- (void)setMaxChannels:(NSUInteger)maxChannels {
    if (_maxChannels != maxChannels) {
        _maxChannels = maxChannels;
        
        [self invalidate];
    }
}

- (NSUInteger)actualNumberOfChannels {
    return _channelsCachedData.count;
}

@end
