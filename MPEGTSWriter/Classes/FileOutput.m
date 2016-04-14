//
//  FileOutput.m
//  VSDK
//
//  Created by Michael Belenchenko on 12/24/15.
//

#import "FileOutput.h"

@interface FileOutput()

@property (copy, nonatomic) NSString *outputPath;
@property (strong, nonatomic) NSFileHandle *fileHandle;

@end

@implementation FileOutput

- (id)initWithPath:(NSString *)outputPath
{
    self = [super init];
    
    if (self)
    {
        _outputPath = outputPath;
    }
    
    return self;
}

- (void)appendData:(NSData *)data
{
    if (self.fileHandle)
    {
        [self.fileHandle writeData:data];
    }
    else
    {
        [data writeToFile:self.outputPath atomically:YES];
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.outputPath];
        [self.fileHandle seekToEndOfFile];
    }
}

- (void)finish
{
    [self.fileHandle closeFile];
}

@end
