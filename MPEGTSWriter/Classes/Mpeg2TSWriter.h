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

@interface Mpeg2TSWriter : NSObject

- (id)initOutputPathPattern:(NSString *)outputPathPattern segmentLength:(float)segmentLength;

- (void)writeVideoFrameData:(NSData *)data sps:(NSData *)sps pps:(NSData *)pps pts:(CMTime)pts dts:(CMTime)dts isSync:(BOOL)isSync;

- (void)writeAudioFrameData:(NSData *)data pts:(CMTime)pts writePCR:(BOOL)pcr;

- (void)finish;

- (void)pause;
- (void)unpause;
- (BOOL)isPaused;


@end