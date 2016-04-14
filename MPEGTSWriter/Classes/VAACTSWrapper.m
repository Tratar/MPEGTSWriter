//
//  VAACTSWrapper.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/16/15.
//

#import "VAACTSWrapper.h"

static const size_t kAdtsHeaderLength = 7;

@interface VAACTSWrapper()

@end

@implementation VAACTSWrapper

static void MakeAdtsHeader(unsigned char bits[7], unsigned int frame_size)
{
    int profile = 2;
    int freqIdx = 4;
    int chanCfg = 1;
    NSUInteger fullLength = 7 + frame_size;
    bits[0] = (char)0xFF;
    bits[1] = (char)0xF9;
    bits[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    bits[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    bits[4] = (char)((fullLength&0x7FF) >> 3);
    bits[5] = (char)(((fullLength&7)<<5) + 0x1F);
    bits[6] = (char)0xFC;
}

- (NSData *)addADTSHeader:(NSData *)data
{
    NSMutableData *buffer = [NSMutableData dataWithLength:kAdtsHeaderLength + [data length]];
    
    MakeAdtsHeader((unsigned char*)[buffer mutableBytes], (unsigned int)[data length]);
    memcpy(((char*)[buffer mutableBytes]) + kAdtsHeaderLength, [data bytes], [data length]);

    return buffer;
}

@end
