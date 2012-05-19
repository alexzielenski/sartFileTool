//
//  SFDescriptor.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/16/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "SFDescriptor.h"
#import "NSData+Byte.h"
#import "SFFileHeader.h"
#import "SFHeader.h"
#import "SArtFile.h"
#import "NSImageRep+Data.h"

@implementation SFDescriptor
@synthesize type        = _type;
@synthesize fileHeaders = _fileHeaders;
@synthesize header      = _header;

+ (SFDescriptor *)descriptor
{
    return [[[self alloc] init] autorelease];
}

+ (SFDescriptor *)descriptorWithData:(NSData *)data header:(SFHeader *)header
{
    return [[[self alloc] initWithData:data header:header] autorelease];
}

- (id)initWithData:(NSData *)data header:(SFHeader *)fileHeader
{
    if ((self = [self init])) {        
        _header = fileHeader;
        
        if (![_fileHeaders isKindOfClass:[NSMutableArray class]])
            _fileHeaders = [[NSMutableArray array] retain];
        
        NSMutableArray *fileHeaders = (NSMutableArray *)_fileHeaders;
        
        _type              = (SFDescriptorType)[data nextShort];
        uint16_t fileCount = [data nextShort];
        
        data.currentOffset += 8; // Skip unknown 2 and 3 on ML
        
        for (int x = 0; x < fileCount; x++) {
            // Length of file headers is 12
            SFFileHeader *header = [SFFileHeader fileHeaderWithData:data range:NSMakeRange(data.currentOffset, 12)];
            
            if (x == 0 && self.type == SFDescriptorTypePDF)
                header.imageClass = [NSPDFImageRep class];
            
            // Set the image data
            NSData *imageData = [data subdataWithRange:NSMakeRange(_header.masterOffset + header.offset, header.length)];
            
            // the first image in PDFs is not raw
            if (self.type == SFDescriptorTypePDF && x == 0) {
                
                header.imageData = imageData;
                
            } else {
                // Process the data to be PNG
                CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)imageData);
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                CGBitmapInfo bitmapInfo = kCGImageAlphaFirst | kCGBitmapByteOrder32Little;

                CGImageRef cgImage = CGImageCreate(header.width, header.height, 8, 32, 4 * header.width, colorSpace, bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault);
                
                NSMutableData *pngData = [NSMutableData dataWithCapacity:0];
                CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)pngData, 
                                                                                     kUTTypePNG, 
                                                                                     1, 
                                                                                     NULL);
                CGImageDestinationAddImage(destination, cgImage, NULL);
                CGImageDestinationFinalize(destination);
                
                CGColorSpaceRelease(colorSpace);
                CGDataProviderRelease(provider);
                CGImageRelease(cgImage);
                CFRelease(destination);
                
                header.imageData = pngData;
            }
            
            [fileHeaders addObject:header];
        }
        
    }
    
    return self;
}

- (id)init
{
    if ((self = [super init])) {
        _fileHeaders = [[NSMutableArray array] retain];
        _type        = SFDescriptorTypePNG;
    }
    
    return self;
}

- (NSData *)headerData
{
    NSMutableData *headerData = [NSMutableData dataWithCapacity:12];
    NSMutableData *fileHeaderData = [NSMutableData dataWithCapacity:12 * self.fileHeaders.count];
    
    uint32_t totalSize  = 0;
    uint32_t unknown2   = 0; // Yeah i don't know this yet. Luckily these two values are dropped in 10.8
    
    uint16_t type  = CFSwapInt16HostToLittle(self.type);
    uint16_t count = CFSwapInt16HostToLittle(self.fileHeaders.count);
    
    for (SFFileHeader *header in self.fileHeaders) {
        [fileHeaderData appendData:header.headerData];
        totalSize += header.expectedRawContentSize;
    }
    
    if (self.type == SFDescriptorTypePDF && self.fileHeaders.count > 0)
        unknown2 = [[self.fileHeaders objectAtIndex:0] expectedRawContentSize] - 47; // Seems to be for PDFs
    
    totalSize = CFSwapInt32HostToLittle(totalSize);
    unknown2  = CFSwapInt32HostToLittle(unknown2);
    
    [headerData appendBytes:&type length:sizeof(type)];
    [headerData appendBytes:&count length:sizeof(count)];
    
    if (self.header.sartFile.minorOSVersion <= 7) { // Gone in 10.8
    
        [headerData appendBytes:&unknown2 length:sizeof(unknown2)];
        [headerData appendBytes:&totalSize length:sizeof(totalSize)];
    
    }
        
    [headerData appendData:fileHeaderData];
    
    return headerData;
}

- (NSUInteger)expectedLength
{
    return 12 + 12 * self.fileHeaders.count;
}

- (void)addFileAtURL:(NSURL *)url
{
    NSString *fileName = url.lastPathComponent;
    
    if ([fileName.pathExtension isEqualToString:@"pdf"])
        self.type = SFDescriptorTypePDF;
    
    SFFileHeader *header = [SFFileHeader fileHeaderWithContentsOfURL:url];
    
    if (self.type == SFDescriptorTypePDF && self.fileHeaders.count == 0)
        header.imageClass = [NSPDFImageRep class];
    
    [self.fileHeaders addObject:header];
    
    if (self.fileHeaders.count > 1 && self.type == SFDescriptorTypePNG)
        self.type = SFDescriptorTypeHiDPIPNG;
    
    // If the PDF's cache images weren't written, write them out homes.
    if (!self.header.sartFile.shouldWritePDFReps && self.type == SFDescriptorTypePDF && self.fileHeaders.count == 1) {
        
        NSPDFImageRep *rep = (NSPDFImageRep *)header.imageRepresentation;
        
        NSBitmapImageRep *legacy = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
                                                                           pixelsWide:rep.pixelsWide 
                                                                           pixelsHigh:rep.pixelsHigh 
                                                                        bitsPerSample:8 
                                                                      samplesPerPixel:4
                                                                             hasAlpha:YES 
                                                                             isPlanar:NO 
                                                                       colorSpaceName:NSCalibratedRGBColorSpace 
                                                                         bitmapFormat:NSAlphaFirstBitmapFormat
                                                                          bytesPerRow:4 * rep.pixelsWide 
                                                                         bitsPerPixel:32];
        NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:legacy];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:ctx];
        
        [rep drawInRect:rep.bounds];

        [NSGraphicsContext restoreGraphicsState];
        

        
        NSBitmapImageRep *retina = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
                                                                           pixelsWide:rep.pixelsWide * 2
                                                                           pixelsHigh:rep.pixelsHigh * 2
                                                                        bitsPerSample:8 
                                                                      samplesPerPixel:4
                                                                             hasAlpha:YES 
                                                                             isPlanar:NO 
                                                                       colorSpaceName:NSCalibratedRGBColorSpace 
                                                                         bitmapFormat:NSAlphaFirstBitmapFormat
                                                                          bytesPerRow:4 * rep.pixelsWide * 2
                                                                         bitsPerPixel:32];
        ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:retina];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:ctx];
        
        [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide * 2, rep.pixelsHigh * 2) 
               fromRect:NSZeroRect 
              operation:NSCompositeSourceOver 
               fraction:1.0 
         respectFlipped:YES 
                  hints:nil];
        
        [NSGraphicsContext restoreGraphicsState];
        
        SFFileHeader *legacyHeader = [[[SFFileHeader alloc] init] autorelease];
        SFFileHeader *retinaHeader = [[[SFFileHeader alloc] init] autorelease];
        
        legacyHeader.imageData = [legacy representationUsingType:NSPNGFileType properties:nil];
        legacyHeader.width     = legacy.pixelsWide;
        legacyHeader.height    = legacy.pixelsHigh;
                
        retinaHeader.imageData = [retina representationUsingType:NSPNGFileType properties:nil];
        retinaHeader.width     = retina.pixelsWide;
        retinaHeader.height    = retina.pixelsHigh;
        
        [self.fileHeaders addObject:legacyHeader];
        [self.fileHeaders addObject:retinaHeader];
        
    }
    
}

@end
