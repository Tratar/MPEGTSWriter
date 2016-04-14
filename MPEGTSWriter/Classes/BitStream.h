//
//  BitStream.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import <Foundation/Foundation.h>

@interface BitStream : NSObject

@property (nonatomic, strong, readonly) NSMutableData *data;

- (void)addBits:(unsigned int)bits subBitsCount:(NSUInteger)subBitsCount;
- (void)addByte:(unsigned char)byte;

@end
