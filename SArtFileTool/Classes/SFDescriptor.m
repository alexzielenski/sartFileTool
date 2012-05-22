//
//  SFDescriptor.m
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
		
        if (_header.sartFile.minorOSVersion <= 7) {
            data.currentOffset += 8; // Skip unknown 2 and 3 on ML
        }
        
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
        _type        = 0;
    }
    
    return self;
}

- (void)dealloc
{
    self.fileHeaders = nil;
    [super dealloc];
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
        unknown2 = (uint32_t)[[self.fileHeaders objectAtIndex:0] expectedRawContentSize] - 47; // Seems to be for PDFs
    
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
    if (self.header.sartFile.minorOSVersion <= 7)
        return 12 + 12 * self.fileHeaders.count;
    return 4 + 12 * self.fileHeaders.count;
}

- (void)addFileAtURL:(NSURL *)url
{
    NSString *fileName = url.lastPathComponent;
    
    if ([fileName.pathExtension isEqualToString:@"pdf"])
        self.type = SFDescriptorTypePDF;
	else if ([fileName.pathExtension isEqualToString:@"tif"] && self.type == 0)
		self.type = SFDescriptorTypeTIF;
	else if (self.type == 0)
		self.type = SFDescriptorTypePNG;
	
    SFFileHeader *header = [SFFileHeader fileHeaderWithContentsOfURL:url];
    
    if (self.type == SFDescriptorTypePDF && self.fileHeaders.count == 0)
        header.imageClass = [NSPDFImageRep class];
    
    [self.fileHeaders addObject:header];
	
	if (self.type == SFDescriptorTypePDF && self.fileHeaders.count == 1) {
		
		// NSPDFImageRep has inaccurate dimension calculation. Let's do it ourselves.
		CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)url);
		CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
		
		CGRect bounds = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
		
		header.width  = (uint16_t)round(bounds.size.width);
		header.height = (uint16_t)round(bounds.size.height);
		
		bounds.size.width  = header.width;
		bounds.size.height = header.height;
		
		// If the PDF's cache images weren't written, write them out homes.
		if (!self.header.sartFile.shouldWritePDFReps) {
			
			NSBitmapImageRep *legacy = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
																			   pixelsWide:bounds.size.width
																			   pixelsHigh:bounds.size.height
																			bitsPerSample:8 
																		  samplesPerPixel:4
																				 hasAlpha:YES 
																				 isPlanar:NO 
																		   colorSpaceName:NSCalibratedRGBColorSpace 
																			 bitmapFormat:NSAlphaFirstBitmapFormat
																			  bytesPerRow:4 * bounds.size.width
																			 bitsPerPixel:32];
			NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:legacy];
			CGContextRef context = [ctx graphicsPort];
			
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:ctx];
			[ctx setShouldAntialias:NO];
			//			CGContextTranslateCTM(context, 0.0, bounds.size.height);
			CGContextScaleCTM(context, 1.0, 1.0);
			
			// Grab the first PDF page
			CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
			
			// CGPDFPageGetDrawingTransform provides an easy way to get the transform for a PDF page. It will scale down to fit, including any
			// base rotations necessary to display the PDF page correctly. 
			CGAffineTransform pdfTransform = CGPDFPageGetDrawingTransform(page, kCGPDFMediaBox, bounds, 0, true);
			
			// And apply the transform.
			CGContextConcatCTM(context, pdfTransform);
			
			// Finally, we draw the page and restore the graphics state for further manipulations!
			CGContextDrawPDFPage(context, page);
			
			[NSGraphicsContext restoreGraphicsState];
			
			
			NSBitmapImageRep *retina = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																			   pixelsWide:bounds.size.width * 2
																			   pixelsHigh:bounds.size.height * 2
																			bitsPerSample:8
																		  samplesPerPixel:4
																				 hasAlpha:YES 
																				 isPlanar:NO 
																		   colorSpaceName:NSCalibratedRGBColorSpace 
																			 bitmapFormat:NSAlphaFirstBitmapFormat
																			  bytesPerRow:4 * bounds.size.width * 2
																			 bitsPerPixel:32];
			ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:retina];
			context = [ctx graphicsPort];
			
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:ctx];
			[ctx setShouldAntialias:NO];
			
			//			CGContextTranslateCTM(context, 0.0, bounds.size.height * 2);
			CGContextScaleCTM(context, 2.0, 2.0);
			
			// CGPDFPageGetDrawingTransform provides an easy way to get the transform for a PDF page. It will scale down to fit, including any
			// base rotations necessary to display the PDF page correctly. 
			pdfTransform = CGPDFPageGetDrawingTransform(page, kCGPDFMediaBox, bounds, 0, true);
			
			// And apply the transform.
			CGContextConcatCTM(context, pdfTransform);
			
			// Finally, we draw the page and restore the graphics state for further manipulations!
			CGContextDrawPDFPage(context, page);
			
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
		CGPDFDocumentRelease(pdf);
	}
}

@end
