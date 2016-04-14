//
//  FileOutput.h
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import <Foundation/Foundation.h>

@interface FileOutput : NSObject

- (id)initWithPath:(NSString *)outputPath;

- (void)appendData:(NSData *)data;
- (void)finish;

@end
