//
//  VAudioAACProcessor.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/16/15.
//

#import "VAudioAACProcessor.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import <Foundation/Foundation.h>

@import AudioToolbox;

@interface VAudioAACProcessor()

@property (assign, nonatomic) BOOL isFinished;
@property (assign, nonatomic) BOOL isInitial;
@property (strong, nonatomic) NSMutableArray *requests;
@property (strong, nonatomic) NSMutableArray *contexts;
@property (strong, nonatomic) NSLock *lock;
@property (assign, nonatomic) AudioStreamBasicDescription outDescription;

@property (nonatomic, assign) AudioConverterRef audioCompressionSession;

@end

@implementation VAudioAACProcessor

- (VAudioAACProcessor *)init
{
    self = [super init];
    
    if (self)
    {
        _requests = [NSMutableArray new];
        _contexts = [NSMutableArray new];
        _lock = [NSLock new];
    }
    
    return self;
}

- (void)addData:(NSData *)data context:(id)context
{
    [self.lock lock];

    if (self.isFinished || !self.isInitial)
        return;

    [self.requests addObject:data];
    [self.contexts addObject:context];
    
    uint32_t bufferSize = 2048;
    uint8_t *buffer = (uint8_t *)malloc(bufferSize);
    memset(buffer, 0, bufferSize);
    AudioBufferList outAudioBufferList;
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = 1;
    outAudioBufferList.mBuffers[0].mDataByteSize = bufferSize;
    outAudioBufferList.mBuffers[0].mData = buffer;
    
    AudioStreamPacketDescription description;
    
    UInt32 ioOutputDataPacketSize = 1;
    int s = AudioConverterFillComplexBuffer(self.audioCompressionSession, inInputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &outAudioBufferList, &description);
    if (s == noErr || s == -1)
    {
        NSData *data = [[NSData alloc] initWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
        if ([self.delegate respondsToSelector:@selector(audioAACProcessor:processedDataWithResult:context:lastData:)])
            [self.delegate audioAACProcessor:self processedDataWithResult:data context:context lastData:self.isFinished];
    }

    free(buffer);
    [self.lock unlock];
}

OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    VAudioAACProcessor *selF = (__bridge VAudioAACProcessor *)inUserData;
    
    NSData *data = [selF.requests firstObject];
    
    if (!data)
    {
        *ioNumberDataPackets = 0;
        return -1;
    }
    
    ioData->mBuffers[0].mData = (void *)[data bytes];
    ioData->mBuffers[0].mDataByteSize = (UInt32)[data length];

    [selF.requests removeObjectAtIndex:0];
    [selF.contexts removeObjectAtIndex:0];
    
    *ioNumberDataPackets = 1;
    return noErr;
}

- (BOOL)initializeWithInputFormatDescription:(AudioStreamBasicDescription *)inDescription
{
    AudioConverterRef audioRef;
    AudioStreamBasicDescription aac = {0};

    aac.mSampleRate = 44100.000000;
    aac.mFormatID = kAudioFormatMPEG4AAC;
    aac.mFramesPerPacket = 1024;
    aac.mChannelsPerFrame = 1;

    AudioClassDescription *description = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer] ;
    OSStatus status = AudioConverterNewSpecific(inDescription, &aac, 1, description, &audioRef);
    
    self.audioCompressionSession = audioRef;
    self.isInitial = (status == noErr && self.audioCompressionSession);
    self.outDescription = aac;
    return status == noErr;
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
         return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

- (void)finish
{
    [self.lock lock];
    self.isFinished = YES;
    [self.lock unlock];
}

@end
