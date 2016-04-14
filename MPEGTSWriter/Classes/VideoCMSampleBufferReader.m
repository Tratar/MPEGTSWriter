//
//  VideoStream.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import <AVFoundation/AVFoundation.h>

#import "VideoCMSampleBufferReader.h"
#import "FileOutput.h"
#import "BitStream.h"
#import "NSData+CRC.h"

@implementation VideoCMSampleBufferReader

- (void)readSampleBuffer:(CMSampleBufferRef)sampleBuffer spsOut:(NSData * __autoreleasing *)spsOut ppsOut:(NSData * __autoreleasing *)ppsOut payloadOut:(NSData * __autoreleasing *)payloadOut pts:(NSValue * __autoreleasing *)pts dts:(NSValue * __autoreleasing *)dts
{
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    CMTime ptsTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime dtsTime = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
    
    bool isKeyframe = false;
    if(attachments != NULL) {
        CFDictionaryRef attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (dependsOnOthers == kCFBooleanFalse);
    }
    
    char *payload;
    NSData *spsData, *ppsData, *payloadData;
    size_t payloadDataSize;
    
    if (isKeyframe)
    {
        const uint8_t *sps, *pps;
        size_t parmCount, spsSize, ppsSize;
        
        int spsSizeLength, ppsSizeLength;
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &parmCount, &spsSizeLength);
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &parmCount, &ppsSizeLength);
        
        spsData = [NSData dataWithBytes:sps length:spsSize];
        ppsData = [NSData dataWithBytes:pps length:ppsSize];
    }
 
    CMBlockBufferGetDataPointer(block, 0, NULL, &payloadDataSize, &payload);
    payloadData = [NSData dataWithBytes:payload length:payloadDataSize];

    *spsOut = spsData;
    *ppsOut = ppsData;
    *payloadOut = payloadData;
    
    *pts = [NSValue valueWithCMTime:ptsTime];
    
    if (dtsTime.value)
        *dts = [NSValue valueWithCMTime:ptsTime];
    else
        *dts = [NSValue valueWithCMTime:dtsTime];
}

@end
