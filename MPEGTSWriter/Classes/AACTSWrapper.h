//
//  VAACTSWrapper.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/16/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AACTSWrapper : NSObject

- (NSData *)addADTSHeader:(NSData *)data;

@end
