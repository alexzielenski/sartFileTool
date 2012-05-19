//
//  SFHeader.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/16/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFDescriptor.h"

@class SArtFile;

@interface SFHeader : NSObject
@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) uint32_t fileCount;
@property (nonatomic, assign) uint32_t masterOffset;
@property (nonatomic, retain) NSMutableArray *descriptors;
@property (nonatomic, assign) SArtFile *sartFile;

// Pass the entire file's data
+ (SFHeader *)headerWithData:(NSData *)data;
- (id)initWithData:(NSData *)data;

+ (SFHeader *)headerWithFolderURL:(NSURL *)url file:(SArtFile *)file;
- (id)initWithFolderURL:(NSURL *)url file:(SArtFile *)file;

- (NSData *)headerData;

@end
