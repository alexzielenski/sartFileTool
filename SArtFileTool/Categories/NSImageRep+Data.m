//
//  NSImageRep+Data.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "NSImageRep+Data.h"
#import <Accelerate/Accelerate.h>

@implementation NSImageRep (DataAdditions)

- (NSData *)sartFileData
{
    // If we are an NSPDFImageRep instance
    if ([self respondsToSelector:@selector(PDFRepresentation)])
        return [self performSelector:@selector(PDFRepresentation)];
    
    if (![self isKindOfClass:[NSBitmapImageRep class]])
        return nil;
    
    NSBitmapImageRep *bitmapSelf = (NSBitmapImageRep *)self;
    NSInteger width  = [bitmapSelf pixelsWide];
    NSInteger height = [bitmapSelf pixelsHigh];
    
    BOOL alphaFirst = (bitmapSelf.bitmapFormat & NSAlphaFirstBitmapFormat);
    
    if (width == 0 || height == 0)
        return nil;
    
    unsigned char *bytes = [bitmapSelf bitmapData];
    
    vImage_Buffer src;
    src.data     = (void*)bytes;
    src.width    = width;
    src.height   = height;
    src.rowBytes = 4 * width;
        
    uint8_t permuteMap[4]; // RGBA

    if (alphaFirst) {
        // ARGB to BGRA
        permuteMap[0] = 3;
        permuteMap[1] = 2;
        permuteMap[2] = 1;
        permuteMap[3] = 0;
    } else {
        // RGBA to BGRA
        permuteMap[0] = 2;
        permuteMap[1] = 1;
        permuteMap[2] = 0;
        permuteMap[3] = 3;
    }
    
    vImagePermuteChannels_ARGB8888(&src, &src, permuteMap, 0);
        
    if (!(bitmapSelf.bitmapFormat & NSAlphaNonpremultipliedBitmapFormat)) {
        vImageUnpremultiplyData_BGRA8888(&src, &src, 0);
    }
    
    return [NSData dataWithBytesNoCopy:src.data length:width * height * 4 freeWhenDone:NO];
    
}

@end
