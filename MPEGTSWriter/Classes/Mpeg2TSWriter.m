//
//  Mpeg2TSFileWriter.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import "Mpeg2TSWriter.h"
#import "MediaStream.h"
#import "BitStream.h"
#import "FileOutput.h"
#import "VAACTSWrapper.h"

#import "NSData+CRC.h"

#define VIDEO_TIME_SCALE 90000

#define PAT_PID 0x0
#define PMT_PID 0x100
#define VIDEO_PID 0x102
#define AUDIO_PID 0x101
#define AUDIO_SID 0xC0
#define VIDEO_SID 0xE0

#define STREAM_TYPE_AAC 0x0F
#define STREAM_TYPE_AVC 0x1B

@interface Mpeg2TSWriterPauseWrapper()

@property (nonatomic, strong) Mpeg2TSWriter *writer;
@property (nonatomic, assign) BOOL requestedPause;
@property (nonatomic, assign) BOOL requestedUnPause;
@property (nonatomic, assign) BOOL semanticallyPaused;
@property (nonatomic, assign) BOOL actuallyPaused;
@property (nonatomic, assign) int64_t pausedTime;
@property (nonatomic, assign) int64_t lastPausedTimestamp;

@end

@implementation Mpeg2TSWriterPauseWrapper

- (id)initWithWriter:(Mpeg2TSWriter *)writer
{
    self = [super init];
    
    if (self)
    {
        _writer = writer;
    }
    
    return self;
}

- (void)writeVideoFrameData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps pts:(CMTime)pts dts:(CMTime)dts isSync:(BOOL)isSync
{
    if (isSync && self.requestedPause)
    {
        self.requestedPause = NO;
        self.actuallyPaused = YES;
        self.lastPausedTimestamp = pts.value;
    }
    
    if (isSync && self.requestedUnPause && self.actuallyPaused)
    {
        self.requestedUnPause = NO;
        self.actuallyPaused = NO;
        self.pausedTime += pts.value - self.lastPausedTimestamp;
    }
    
    if (!self.actuallyPaused)
    {
        pts.value -= self.pausedTime;
        dts.value -= self.pausedTime;
        [self.writer writeVideoFrameData:data sps:sps pps:pps pts:pts dts:dts isSync:isSync];
    }
}

- (void)writeAudioFrameData:(NSData *)data pts:(CMTime)pts writePCR:(BOOL)pcr
{
    if (!self.actuallyPaused)
    {
        pts.value -= self.pausedTime;
        [self.writer writeAudioFrameData:data pts:pts writePCR:pcr];
    }
}

- (void)finish
{
    [self.writer finish];
}

- (void)pause
{
    self.requestedPause = YES;
    self.semanticallyPaused = YES;
}

- (void)unpause
{
    self.requestedUnPause = YES;
    self.semanticallyPaused = NO;
}

- (BOOL)isPaused
{
    return self.semanticallyPaused;
}

@end

@interface Mpeg2TSWriter()

@property (nonatomic, strong) Stream *pat;
@property (nonatomic, strong) Stream *pmt;
@property (nonatomic, strong) MediaStream *audioStream;
@property (nonatomic, strong) MediaStream *videoStream;
@property (nonatomic, strong) FileOutput *fileOutput;

@property (nonatomic, assign) BOOL isFinished;

@property (nonatomic, assign) double currentVideoDuration;
@property (nonatomic, assign) double currentAudioDuration;
@property (nonatomic, assign) unsigned int audioFramesCount;
@property (nonatomic, assign) unsigned int videoFramesCount;
@property (nonatomic, assign) unsigned int currentSegment;
@property (nonatomic, assign) double lastAudioTs;
@property (nonatomic, assign) double lastVideoTs;
@property (nonatomic, assign) double lastTs;
@property (nonatomic, assign) double desirableSegmentDuration;
@property (nonatomic, assign) unsigned long long startPTS;

@property (nonatomic, strong) NSMutableArray *durations;
@property (nonatomic, strong) VAACTSWrapper *AACTSWrapper;

@property (nonatomic, copy) NSString *outputPathPattern;

@end

@implementation Mpeg2TSWriter

- (id)initOutputPath:(NSString *)outputPath segmentLength:(float)segmentLength
{
    self = [super init];
    
    if (self)
    {
        _audioStream = [[MediaStream alloc] initWithPid:AUDIO_PID streamID:AUDIO_PID streamType:STREAM_TYPE_AAC timeScale:VIDEO_TIME_SCALE isVideoStream:NO];

        _videoStream = [[MediaStream alloc] initWithPid:VIDEO_PID streamID:VIDEO_SID streamType:STREAM_TYPE_AVC timeScale:VIDEO_TIME_SCALE isVideoStream:YES];
        
        _pat = [[Stream alloc] initWithPid:PAT_PID];
        _pmt = [[Stream alloc] initWithPid:PMT_PID];
        
        _durations = [NSMutableArray new];
        _outputPathPattern = outputPath;
        _desirableSegmentDuration = segmentLength;
        _AACTSWrapper = [[VAACTSWrapper alloc] init];
    }
    
    return self;
}

- (void)writeVideoFrameData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps pts:(CMTime)pts dts:(CMTime)dts isSync:(BOOL)isSync
{
    @synchronized(self)
    {
        if (self.isFinished)
            return;

        unsigned long long ptsVal = CMTimeConvertScale(pts, VIDEO_TIME_SCALE, kCMTimeRoundingMethod_Default).value;
        unsigned long long dtsVal = CMTimeConvertScale(dts, VIDEO_TIME_SCALE, kCMTimeRoundingMethod_Default).value;
    
        if (self.startPTS == 0)
            self.startPTS = ptsVal;
    
        ptsVal -= self.startPTS;
        dtsVal = dtsVal ? dtsVal - self.startPTS : 0;
    
        NSData *pesData = [self.videoStream PESVideoDataByData:data sps:sps pps:pps delimiter:YES];
    
        [self writePES:pesData pts:@(ptsVal) dts:(dtsVal == 0 ? @(ptsVal) : @(ptsVal)) withPCR:YES isSync:isSync stream:self.videoStream];
    }
}

- (void)writeAudioFrameData:(NSData *)data pts:(CMTime)pts writePCR:(BOOL)pcr
{
    @synchronized(self)
    {
        if (self.isFinished)
            return;

        unsigned long long ts = CMTimeConvertScale(pts, VIDEO_TIME_SCALE, kCMTimeRoundingMethod_Default).value;
    
        if (self.startPTS == 0)
            self.startPTS = ts;
    
        [self writePES:[self.AACTSWrapper addADTSHeader:data] pts:@(ts - self.startPTS) dts:nil withPCR:YES isSync:NO stream:self.audioStream];
    }
}

- (NSUInteger)writePES:(NSData *)data pts:(NSNumber *)pts dts:(NSNumber *)dts withPCR:(BOOL)withPCR isSync:(BOOL)isSync stream:(MediaStream *)stream
{
    BOOL isVideo = stream == self.videoStream;

    if (isSync)
    {
        if (isVideo)
        {
            double diff = (double)[pts unsignedLongLongValue]/(double)stream.timeScale - self.lastVideoTs;
            self.currentVideoDuration += diff;
            self.lastVideoTs = (double)[pts unsignedLongLongValue]/(double)stream.timeScale;
        }
        else
        {
            double diff = (double)[pts unsignedLongLongValue]/(double)stream.timeScale - self.lastVideoTs;
            self.currentVideoDuration += diff;
            self.lastAudioTs = (double)[pts unsignedLongLongValue]/(double)stream.timeScale;
        }
            
        if (self.currentVideoDuration >= self.desirableSegmentDuration || self.currentAudioDuration >= self.desirableSegmentDuration)
        {
            [self finalizeCurrentSegment];
        }
    }
        
    [self initFileOutputIfNeed];
        
    if (isVideo)
    {
        ++self.videoFramesCount;
        [stream writePESToOutput:self.fileOutput data:data pts:pts dts:dts writePCR:withPCR syncFrame:isSync];
        printf("\n222 %lld %d", [pts unsignedLongLongValue], isSync);
    }
    else
    {
        ++self.audioFramesCount;
        [stream writePESToOutput:self.fileOutput data:data pts:pts dts:nil writePCR:withPCR syncFrame:isSync];
        printf("\n111 %lld", [pts unsignedLongLongValue]);
    }
    return 1;
}

- (void)initFileOutputIfNeed
{
    if (!self.fileOutput)
    {
        self.fileOutput = [self openOutput:[NSString stringWithFormat:self.outputPathPattern, self.currentSegment]];
        [self.pat writePATTOOutput:self.fileOutput pmt:self.pmt];
        [self.pmt writePMTTOOutput:self.fileOutput audioStream:self.audioStream videoStream:self.videoStream];
    }
}

- (void)finalizeCurrentSegment
{
    if (self.fileOutput)
    {
        [self.durations addObject:@(self.currentVideoDuration)];
        NSLog(@"Segment %d, duration=%.2f, %d audio samples, %d video samples", self.currentSegment, self.currentVideoDuration, self.audioFramesCount, self.videoFramesCount);
        self.currentVideoDuration = 0;
        self.currentAudioDuration = 0;
        [self.fileOutput finish];
        self.fileOutput = nil;
        self.audioFramesCount = 0;
        self.videoFramesCount = 0;
        ++self.currentSegment;
    }

    [self initFileOutputIfNeed];
}

- (void)finish
{
    @synchronized(self)
    {
        if (self.isFinished) return;
        self.isFinished = true;

        if (self.fileOutput) {
            NSLog(@"Segment %d, duration=%.2f, %d audio samples, %d video samples", self.currentSegment,
                  self.currentVideoDuration,
                  self.audioFramesCount,
                  self.videoFramesCount);
            [self.fileOutput finish];
            self.fileOutput = nil;
            ++self.currentSegment;
            self.audioFramesCount = 0;
            self.videoFramesCount = 0;
            [self.durations addObject:@(self.currentVideoDuration)];
        }
    }
}

- (FileOutput *)openOutput:(NSString *)path
{
    return [[FileOutput alloc] initWithPath:path];
}

@end
