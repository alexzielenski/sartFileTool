//
//  SFFileHeader.m
//  SArtFileTool
//
//  Copyright (c) 2011-2012, Alex Zielenski
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided 
//  that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this list of conditions and the 
//    following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the 
//    following disclaimer in the documentation and/or other materials provided with the distribution.
//  * Any redistribution, use, or modification is done solely for personal benefit and not for any commercial 
//    purpose or for monetary gain

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS 
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
//  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY 
//  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SFFileHeader.h"
#import "NSData+Byte.h"
#import "NSImageRep+Data.h"

@implementation SFFileHeader

@synthesize width      = _width;
@synthesize height     = _height;
@synthesize length     = _length;
@synthesize offset     = _offset;
@synthesize imageRepresentation = _imageRepresentation;

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
        
        // Get the size
        Class repClass = ([url.pathExtension.lowercaseString isEqualToString:@"pdf"]) ? [NSPDFImageRep class] : [NSBitmapImageRep class];
        NSImageRep *imageInstance = [[[repClass alloc] initWithData:data] autorelease];

        self.imageRepresentation = imageInstance;
        
		self.width  = (uint16_t)imageInstance.pixelsWide;
		self.height = (uint16_t)imageInstance.pixelsHigh;
    }
    
    return self;
}

- (id)init
{
    if ((self = [super init])) {        
        _width  = 1;
        _height = 1;
        _length = 1 * 1 * 4;
        _offset = 0;
    }
    
    return self;
}

- (void)dealloc
{
    self.imageRepresentation = nil;
    [super dealloc];
}

- (NSData *)imageData
{
    if ([self.imageRepresentation isKindOfClass:[NSPDFImageRep class]])
        return [(NSPDFImageRep *)self.imageRepresentation PDFRepresentation];
    return [(NSBitmapImageRep *)self.imageRepresentation representationUsingType:NSPNGFileType properties:nil];
}

- (NSData *)headerData
{
    NSMutableData *data = [NSMutableData dataWithCapacity:12];
    
    uint16_t width  = CFSwapInt16HostToLittle(self.width);
    uint16_t height = CFSwapInt16HostToLittle(self.height);
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)self.expectedRawContentSize);
    uint32_t offset = CFSwapInt32HostToLittle(self.offset);
	    
    [data appendBytes:&width length:sizeof(uint16_t)];
    [data appendBytes:&height length:sizeof(uint16_t)];
    [data appendBytes:&length length:sizeof(uint32_t)];
    [data appendBytes:&offset length:sizeof(uint32_t)];
        
    return data;
}

- (NSData *)sartFileData
{    
    // Process the PNG Data to be ABGR
    return self.imageRepresentation.sartFileData;
}

- (NSUInteger)expectedRawContentSize
{
    if ([self.imageRepresentation isKindOfClass:[NSPDFImageRep class]])
        return [[(NSPDFImageRep *)self.imageRepresentation PDFRepresentation] length];
    
    return self.width * self.height * 4;
}

@end
