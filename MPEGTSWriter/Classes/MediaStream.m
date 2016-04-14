//
//  MediaStream.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/28/15.
//

#import "MediaStream.h"
#import "BitStream.h"
#import "FileOutput.h"
#import "NSData+CRC.h"

#define PACKET_SIZE 188
#define PAYLOAD_SIZE 184
#define START_BYTE 0x47
#define PCR_ADAPT_SIZE 6

@interface Stream()

@property (assign, nonatomic) unsigned short pid;

@end

@implementation Stream

- (id)initWithPid:(unsigned short)pid
{
    self = [super init];
    
    if (self)
    {
        _pid = pid;
    }
    
    return self;
}

- (unsigned int)writeHeaderToOutput:(FileOutput *)fileOutput isStart:(BOOL)isStart payloadSize:(unsigned int)payloadSize withPCR:(BOOL)withPCR pcr:(unsigned long long)pcr
{
    BitStream *headerStream = [BitStream new];
    
    [headerStream addByte:START_BYTE];
    [headerStream addByte:(unsigned char)(((isStart?1:0)<<6) | (self.pid >> 8))];
    [headerStream addByte:self.pid & 0xFF];
    
    unsigned int adaptation_field_size = 0;
    if (withPCR)
        adaptation_field_size += 2 + PCR_ADAPT_SIZE;
    
    payloadSize = (payloadSize + adaptation_field_size > PAYLOAD_SIZE) ? PAYLOAD_SIZE - adaptation_field_size : payloadSize;
    
    adaptation_field_size = (adaptation_field_size + payloadSize < PAYLOAD_SIZE) ?  PAYLOAD_SIZE - payloadSize : adaptation_field_size;
    
    if (adaptation_field_size > 0)
    {
        [headerStream addByte:(3<<4) | ((self.continuityCounter++)&0x0F)];
        [fileOutput appendData:headerStream.data];
        
        if (adaptation_field_size == 1)
        {
            unsigned char zero = 0;
            [fileOutput appendData:[NSData dataWithBytes:&zero length:1]];
        }
        else
        {
            unsigned char adapt = adaptation_field_size-1;
            [fileOutput appendData:[NSData dataWithBytes:&adapt length:1]];

            BitStream *pcrStream = [BitStream new];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:withPCR subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [pcrStream addBits:0 subBitsCount:1];
            [fileOutput appendData:[pcrStream data]];

            unsigned int pcr_size = 0;
            if (withPCR)
            {
                pcr_size = PCR_ADAPT_SIZE;
                unsigned long long pcr_base = pcr/ 300;
                unsigned int pcr_ext  = pcr%300;
                BitStream *stream = [[BitStream alloc] init];
                [stream addBits:(unsigned int)(pcr_base>>32) subBitsCount:1];
                [stream addBits:(unsigned int)pcr_base subBitsCount:32];
                [stream addBits:0x3F subBitsCount:6];
                [stream addBits:pcr_ext subBitsCount:9];
                [fileOutput appendData:stream.data];
            }
            if (adaptation_field_size > 2)
            {
                [fileOutput appendData:[self stuffingBytesWithLength:adaptation_field_size-pcr_size-2]];
            }
        }
    }
    else
    {
        [headerStream addByte:(1<<4) | ((self.continuityCounter++)&0x0F)];
        [fileOutput appendData:headerStream.data];
    }
    
    return payloadSize;
}

- (void)writePMTTOOutput:(FileOutput *)fileOutput audioStream:(MediaStream *)audioStream videoStream:(MediaStream *)videoStream
{
    unsigned int payload_size = PAYLOAD_SIZE;
    
    [self writeHeaderToOutput:fileOutput isStart:YES payloadSize:payload_size withPCR:NO pcr:0];
    
    BitStream *stream = [[BitStream alloc] init];
    
    unsigned int section_length = 13;
    unsigned int pcr_pid = 0;
    
    if (audioStream) {
        section_length += 5;
        pcr_pid = audioStream.pid;
    }
    if (videoStream) {
        section_length += 5;
        pcr_pid = videoStream.pid;
    }
    
    [stream addBits:0 subBitsCount:8];
    [stream addBits:2 subBitsCount:8];
    [stream addBits:1 subBitsCount:1];
    [stream addBits:0 subBitsCount:1];
    [stream addBits:3 subBitsCount:2];
    [stream addBits:section_length subBitsCount:12];
    [stream addBits:1 subBitsCount:16];
    [stream addBits:3 subBitsCount:2];
    [stream addBits:0 subBitsCount:5];
    [stream addBits:1 subBitsCount:1];
    [stream addBits:0 subBitsCount:8];
    [stream addBits:0 subBitsCount:8];
    [stream addBits:7 subBitsCount:3];
    [stream addBits:pcr_pid subBitsCount:13];
    [stream addBits:0xF subBitsCount:4];
    [stream addBits:0 subBitsCount:12];
    
    if (audioStream) {
        [stream addBits:audioStream.streamType subBitsCount:8];
        [stream addBits:0x7 subBitsCount:3];
        [stream addBits:audioStream.pid subBitsCount:13];
        [stream addBits:0xF subBitsCount:4];
        [stream addBits:0 subBitsCount:12];
    }
    
    if (videoStream) {
        [stream addBits:videoStream.streamType subBitsCount:8];
        [stream addBits:0x7 subBitsCount:3];
        [stream addBits:videoStream.pid subBitsCount:13];
        [stream addBits:0xF subBitsCount:4];
        [stream addBits:0 subBitsCount:12];
    }
    
    NSData *subData = [[NSData alloc] initWithBytes:((unsigned char *)[stream.data mutableBytes] + 1) length:section_length - 1];
    [stream addBits:[subData crc] subBitsCount:32];
    
    [fileOutput appendData:stream.data];
    [fileOutput appendData:[self stuffingBytesWithLength:PAYLOAD_SIZE - (section_length + 4)]];
}

- (void)writePATTOOutput:(FileOutput *)fileOutput pmt:(Stream *)pmt
{
    unsigned int payload_size = PAYLOAD_SIZE;
    [self writeHeaderToOutput:fileOutput isStart:YES payloadSize:payload_size withPCR:NO pcr:0];
    
    BitStream *stream = [BitStream new];
    
    [stream addBits:0 subBitsCount:8];
    [stream addBits:0 subBitsCount:8];
    [stream addBits:1 subBitsCount:1];
    [stream addBits:0 subBitsCount:1];
    [stream addBits:3 subBitsCount:2];
    [stream addBits:13 subBitsCount:12];
    [stream addBits:1 subBitsCount:16];
    [stream addBits:3 subBitsCount:2];
    [stream addBits:0 subBitsCount:5];
    [stream addBits:1 subBitsCount:1];
    [stream addBits:0 subBitsCount:8];
    [stream addBits:0 subBitsCount:8];
    [stream addBits:1 subBitsCount:16];
    [stream addBits:7 subBitsCount:3];
    [stream addBits:pmt.pid subBitsCount:13];
    
    NSData *subData = [stream.data subdataWithRange:NSMakeRange(1, 17 - 1 - 4)];
   
    [stream addBits:[subData crc] subBitsCount:32];
    
    [fileOutput appendData:stream.data];
    [fileOutput appendData:[self stuffingBytesWithLength:PAYLOAD_SIZE - 17]];
}

- (NSData *)stuffingBytesWithLength:(unsigned int)length
{
    unsigned char ff = 0xFF;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:length];
    for (;length > 0; length --)
    {
        [data appendBytes:&ff length:1];
    }
    return data;
}

- (NSData *)naluStartCodeShort
{
    unsigned char naluStartCodeShort[3];
    
    naluStartCodeShort[0] = 0;
    naluStartCodeShort[1] = 0;
    naluStartCodeShort[2] = 1;
    
    return [NSData dataWithBytes:naluStartCodeShort length:3];
}

- (NSData *)naluStartCodeLong
{
    unsigned char naluStartCodeShort[4];
    
    naluStartCodeShort[0] = 0;
    naluStartCodeShort[1] = 0;
    naluStartCodeShort[2] = 0;
    naluStartCodeShort[3] = 1;
    
    return [NSData dataWithBytes:naluStartCodeShort length:4];
}

- (NSData *)delimiterNalu
{
    unsigned char delimiterNalu[2];
    
    delimiterNalu[0] = 9;
    delimiterNalu[1] = 0xF0;
    
    return [NSData dataWithBytes:delimiterNalu length:2];
}

@end

@interface MediaStream()

@property (assign, nonatomic) unsigned short streamID;
@property (assign, nonatomic) unsigned char streamType;
@property (assign, nonatomic) int timeScale;
@property (assign, nonatomic) int isVideoStream;

@end

@implementation MediaStream

- (id)initWithPid:(unsigned short)pid streamID:(unsigned short)streamID streamType:(unsigned char)streamType timeScale:(int)timeScale isVideoStream:(BOOL)isVideoStream
{
    self = [super initWithPid:pid];
    
    if (self)
    {
        _streamID = streamID;
        _streamType = streamType;
        _timeScale = timeScale;
        _isVideoStream = isVideoStream;
    }
    
    return self;
}

- (NSData *)PESVideoDataByData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps delimiter:(BOOL)delimiter
{
    NSMutableData *resultData = [[NSMutableData alloc] init];
    
    if (delimiter)
    {
        [resultData appendData:[self naluStartCodeLong]];
        [resultData appendData:[self delimiterNalu]];
    }
    
    if (sps)
    {
        [resultData appendData:[self naluStartCodeLong]];
        [resultData appendData:sps];
    }
    
    if (pps)
    {
        [resultData appendData:[self naluStartCodeLong]];
        [resultData appendData:pps];
    }
    
    size_t totalLength = [data length];
    
    size_t bufferOffset = 0;
    static const int AVCCHeaderLength = 4;
    while (bufferOffset < totalLength - AVCCHeaderLength) {
        uint32_t NALUnitLength = 0;
        memcpy(&NALUnitLength, (char *)[data bytes] + bufferOffset, AVCCHeaderLength);
        
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
        
        [resultData appendData:[self naluStartCodeShort]];
        [resultData appendBytes:((char *)[data bytes] + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
        
        bufferOffset += AVCCHeaderLength + NALUnitLength;
    }
    
    return resultData;
}

- (void)writePESToOutput:(FileOutput *)fileOutput data:(NSData *)data pts:(NSNumber *)pts dts:(NSNumber *)dts writePCR:(BOOL)withPCR syncFrame:(BOOL)syncFrame
{
    unsigned int pes_header_size = 14+(dts?5:0);
    BitStream *headerStream = [[BitStream alloc] init];
    
    [headerStream addBits:0x000001 subBitsCount:24];
    [headerStream addBits:self.streamID subBitsCount:8];
    [headerStream addBits:self.isVideoStream ? 0 : ((unsigned int)[data length] + pes_header_size - 6) subBitsCount:16];
    
    [headerStream addBits:2 subBitsCount:2];
    [headerStream addBits:0 subBitsCount:2];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:1 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:1 subBitsCount:2];
    [headerStream addBits:dts != nil subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:0 subBitsCount:1];
    [headerStream addBits:pes_header_size-9 subBitsCount:8];
    [headerStream addBits:1 subBitsCount:3];
    [headerStream addBits:dts != nil subBitsCount:1];
    [headerStream addBits:(unsigned int)([pts unsignedLongLongValue]>>30) subBitsCount:3];
    [headerStream addBits:1 subBitsCount:1];
    [headerStream addBits:(unsigned int)([pts unsignedLongLongValue]>>15) subBitsCount:15];
    [headerStream addBits:1 subBitsCount:1];
    [headerStream addBits:(unsigned int)[pts unsignedLongLongValue] subBitsCount:15];
    [headerStream addBits:1 subBitsCount:1];
    
    if (dts) {
        [headerStream addBits:1 subBitsCount:4];
        [headerStream addBits:(unsigned int)([dts unsignedLongLongValue]>>30) subBitsCount:3];
        [headerStream addBits:1 subBitsCount:1];
        [headerStream addBits:(unsigned int)([dts unsignedLongLongValue]>>15) subBitsCount:15];
        [headerStream addBits:1 subBitsCount:1];
        [headerStream addBits:(unsigned int)[dts unsignedLongLongValue] subBitsCount:15];
        [headerStream addBits:1 subBitsCount:1];
    }
    
    bool first_packet = true;
    unsigned int dataSize = (unsigned int)[data length] + pes_header_size;
    unsigned int dataOffset = 0;
    while (dataSize) {
        unsigned int payload_size = MIN(dataSize, PAYLOAD_SIZE);
        
        if (first_packet)  {
            payload_size = [self writeHeaderToOutput:fileOutput isStart:first_packet payloadSize:payload_size withPCR:withPCR pcr:(dts?[dts unsignedLongLongValue]:[pts unsignedLongLongValue])*300];
            first_packet = false;
            [fileOutput appendData:headerStream.data];
            NSData *dataToWrite = [data subdataWithRange:NSMakeRange(dataOffset, payload_size-pes_header_size)];
            
            [fileOutput appendData:dataToWrite];
            dataOffset += payload_size-pes_header_size;
        } else {
            payload_size = [self writeHeaderToOutput:fileOutput isStart:first_packet payloadSize:payload_size withPCR:NO pcr:0];
            NSData *dataToWrite = [data subdataWithRange:NSMakeRange(dataOffset, payload_size)];
            [fileOutput appendData:dataToWrite];
            dataOffset += payload_size;
        }
        dataSize -= payload_size;
    }
}

@end
