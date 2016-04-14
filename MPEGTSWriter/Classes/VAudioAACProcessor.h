//
//  VAudioAACProcessor.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/16/15.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol VAudioAACProcessorDelegate;

@interface VAudioAACProcessor : NSObject

@property (weak, nonatomic) id<VAudioAACProcessorDelegate> delegate;
@property (readonly, nonatomic) AudioStreamBasicDescription outDescription;

- (void)addData:(NSData *)data context:(id)context;
- (BOOL)initializeWithInputFormatDescription:(AudioStreamBasicDescription *)inDescription;
- (void)finish;

@end

@protocol VAudioAACProcessorDelegate<NSObject>

- (void)audioAACProcessor:(VAudioAACProcessor *)audioAACProcessor processedDataWithResult:(NSData *)data context:(NSObject *)context lastData:(BOOL)lastData;

@end