//
//  MediaStream.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/28/15.
//

#import <Foundation/Foundation.h>


@class FileOutput;
@class MediaStream;

@interface Stream : NSObject

@property (readonly, nonatomic) unsigned short pid;
@property (assign, nonatomic) unsigned int continuityCounter;

- (id)initWithPid:(unsigned short)pid;

- (unsigned int)writeHeaderToOutput:(FileOutput *)fileOutput isStart:(BOOL)isStart payloadSize:(unsigned int)payloadSize withPCR:(BOOL)withPCR pcr:(unsigned long long)pcr;

- (void)writePMTTOOutput:(FileOutput *)fileOutput audioStream:(MediaStream *)audioStream videoStream:(MediaStream *)videoStream;

- (void)writePATTOOutput:(FileOutput *)fileOutput pmt:(Stream *)pmt;

@end

@interface MediaStream : Stream

@property (readonly, nonatomic) unsigned short streamID;
@property (readonly, nonatomic) unsigned char streamType;
@property (readonly, nonatomic) int timeScale;
@property (readonly, nonatomic) int isVideoStream;

- (id)initWithPid:(unsigned short)pid streamID:(unsigned short)streamID streamType:(unsigned char)streamType timeScale:(int)timeScale isVideoStream:(BOOL)isVideoStream;

- (NSData *)PESVideoDataByData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps delimiter:(BOOL)delimiter;

- (void)writePESToOutput:(FileOutput *)fileOutput data:(NSData *)data pts:(NSNumber *)pts dts:(NSNumber *)dts writePCR:(BOOL)withPCR syncFrame:(BOOL)syncFrame;

@end
