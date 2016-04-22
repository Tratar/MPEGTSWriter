//
//  VAudioAACProcessor.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/16/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol AudioAACProcessorDelegate;

@interface AudioAACProcessor : NSObject

@property (weak, nonatomic) id<AudioAACProcessorDelegate> delegate;
@property (readonly, nonatomic) AudioStreamBasicDescription outDescription;

- (void)addData:(NSData *)data context:(id)context;
- (BOOL)initializeWithInputFormatDescription:(AudioStreamBasicDescription *)inDescription;
- (void)finish;

@end

@protocol AudioAACProcessorDelegate<NSObject>

- (void)audioAACProcessor:(AudioAACProcessor *)audioAACProcessor processedDataWithResult:(NSData *)data context:(NSObject *)context lastData:(BOOL)lastData;

@end