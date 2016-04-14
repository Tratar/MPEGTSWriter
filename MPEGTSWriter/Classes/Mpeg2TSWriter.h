//
//  Mpeg2TSFileWriter.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class FileOutput;
@class Mpeg2TSWriter;

@protocol Mpeg2TSWriterProtocol <NSObject>

- (void)writeVideoFrameData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps pts:(CMTime)pts dts:(CMTime)dts isSync:(BOOL)isSync;

- (void)writeAudioFrameData:(NSData *)data pts:(CMTime)pts writePCR:(BOOL)pcr;

@end

@interface Mpeg2TSWriterPauseWrapper : NSObject<Mpeg2TSWriterProtocol>

- (id)initWithWriter:(Mpeg2TSWriter *)writer;

- (void)finish;
- (void)pause;
- (void)unpause;

- (BOOL)isPaused;

@end

@interface Mpeg2TSWriter : NSObject<Mpeg2TSWriterProtocol>

- (id)initOutputPath:(NSString *)outputPath segmentLength:(float)segmentLength;

- (void)finish;

@end
