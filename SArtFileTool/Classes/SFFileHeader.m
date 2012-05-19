//
//  SFFileHeader.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "SFFileHeader.h"
#import "NSData+Byte.h"
#import "NSImageRep+Data.h"

@implementation SFFileHeader

@synthesize width     = _width;
@synthesize height    = _height;
@synthesize length    = _length;
@synthesize offset    = _offset;
@synthesize imageData = _imageData;
@synthesize imageClass = _imageClass;

+ (SFFileHeader *)fileHeaderWithData:(NSData *)data range:(NSRange)range
{
    return [[[self alloc] initWithData:data range:range] autorelease];
}

- (id)initWithData:(NSData *)data range:(NSRange)range
{
    if ((self = [self init])) {
        data.currentOffset = range.location;
        
        _width  = [data nextShort];
        _height = [data nextShort];
        _length = [data nextInt];
        _offset = [data nextInt];
    }
    
    return self;
}

+ (SFFileHeader *)fileHeaderWithContentsOfURL:(NSURL *)url
{
    return [[[self alloc] initWithContentsOfURL:url] autorelease];
}

- (id)initWithContentsOfURL:(NSURL *)url
{
    if ((self = [self init])) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        self.imageData = data;
        
        // Get the size
        Class repClass = ([url.pathExtension.lowercaseString isEqualToString:@"pdf"]) ? [NSPDFImageRep class] : [NSBitmapImageRep class];
        NSImageRep *imageInstance = [[[repClass alloc] initWithData:data] autorelease];
                
        self.width  = (uint16_t)imageInstance.pixelsWide;
        self.height = (uint16_t)imageInstance.pixelsHigh;

        
    }
    
    return self;
}

- (id)init
{
    if ((self = [super init])) {
        _imageClass = [NSBitmapImageRep class];
        
        _width  = 1;
        _height = 1;
        _length = 1 * 1 * 4;
        _offset = 0;
    }
    
    return self;
}

- (NSImageRep *)imageRepresentation
{
    return [[[self.imageClass alloc] initWithData:self.imageData] autorelease];
}

- (NSData *)headerData
{
    NSMutableData *data = [NSMutableData dataWithCapacity:12];
    
    uint16_t width  = CFSwapInt16HostToLittle(self.width);
    uint16_t height = CFSwapInt16HostToLittle(self.height);
    uint32_t length = CFSwapInt32HostToLittle(self.expectedRawContentSize);
    uint32_t offset = CFSwapInt32HostToLittle(self.offset);
    
    [data appendBytes:&width length:sizeof(uint16_t)];
    [data appendBytes:&height length:sizeof(uint16_t)];
    [data appendBytes:&length length:sizeof(uint32_t)];
    [data appendBytes:&offset length:sizeof(uint32_t)];
        
    return data;
}

- (NSData *)sartFileData
{
    if (self.imageClass == [NSPDFImageRep class]) {
        return self.imageData;
    }
    
    // Process the PNG Data to be ABGR
    return self.imageRepresentation.sartFileData;
}

- (NSUInteger)expectedRawContentSize
{
    if (self.imageClass == [NSPDFImageRep class])
        return self.imageData.length;
    
    return self.width * self.height * 4;
}

@end
