//
//  SFDescriptor.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/16/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFFileHeader.h"

@class SFHeader;

typedef enum {
    SFDescriptorTypeHiDPIPNG = 1,
    SFDescriptorTypePNG      = 2,
    SFDescriptorTypePDF      = 3
} SFDescriptorType;

@interface SFDescriptor : NSObject
@property (nonatomic, assign) SFDescriptorType type;
@property (nonatomic, retain) NSMutableArray *fileHeaders;
@property (atomic, assign)    SFHeader *header;

+ (SFDescriptor *)descriptor;

+ (SFDescriptor *)descriptorWithData:(NSData *)data header:(SFHeader *)header;
- (id)initWithData:(NSData *)data header:(SFHeader *)header;

- (NSData *)headerData;
- (NSUInteger)expectedLength;

- (void)addFileAtURL:(NSURL *)url;

@end
