//
//  BitStream.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import "BitStream.h"

@interface BitStream()

@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, assign) unsigned char bitCount;

@end

@implementation BitStream

- (id)init
{
    self = [super init];
    
    if (self)
    {
        _data = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void)addBits:(unsigned int)bits subBitsCount:(NSUInteger)subBitsCount
{
    unsigned char startedBit = 32 - subBitsCount;
    unsigned char zero = 0x0;
   
    while (subBitsCount)
    {
        self.bitCount %= 8;
        if (self.bitCount == 0)
            [self.data appendData:[NSData dataWithBytes:&zero length:1]];

        unsigned char bitsToPut = MIN(8 - self.bitCount, subBitsCount);
        unsigned int bitsToMerge = ((bits << startedBit) >> (32 - bitsToPut)) << (8 - (bitsToPut + self.bitCount));
        (((unsigned char *)[self.data mutableBytes])[[self.data length] - 1]) ^= bitsToMerge;
        
        subBitsCount -= bitsToPut;
        startedBit += bitsToPut;
        self.bitCount += bitsToPut;
    }
}

- (void)addByte:(unsigned char)byte
{
    [self addBits:byte subBitsCount:8];
}

@end
