//
//  VideoStream.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoCMSampleBufferReader : NSObject

- (void)readSampleBuffer:(CMSampleBufferRef)sampleBuffer spsOut:(NSData * __autoreleasing *)spsOut ppsOut:(NSData * __autoreleasing *)ppsOut payloadOut:(NSData * __autoreleasing *)payloadOut pts:(NSValue * __autoreleasing *)pts dts:(NSValue * __autoreleasing *)dts;

@end
