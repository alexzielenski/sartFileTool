//
//  SFFileHeader.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SFFileHeader : NSObject
@property (nonatomic, assign) uint16_t width;
@property (nonatomic, assign) uint16_t height;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, assign) uint32_t offset;
@property (nonatomic, retain) NSData   *imageData;
@property (nonatomic, assign) Class    imageClass;

+ (SFFileHeader *)fileHeaderWithData:(NSData *)data range:(NSRange)range;
- (id)initWithData:(NSData *)data range:(NSRange)range;

+ (SFFileHeader *)fileHeaderWithContentsOfURL:(NSURL *)url;
- (id)initWithContentsOfURL:(NSURL *)url;

- (NSImageRep *)imageRepresentation;

- (NSData *)headerData;
- (NSData *)sartFileData;

- (NSUInteger)expectedRawContentSize;

@end
