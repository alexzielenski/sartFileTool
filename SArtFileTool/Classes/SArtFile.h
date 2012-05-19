//
//  SArtFile.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/16/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFHeader.h"

// Objective-C class wrapper around the SArtFile.bin
@interface SArtFile : NSObject

@property (nonatomic, readonly) SFHeader *header;

// Options
@property (nonatomic, assign) BOOL shouldWritePDFReps;
@property (nonatomic, assign) int  majorOSVersion;
@property (nonatomic, assign) int  minorOSVersion;
@property (nonatomic, assign) int  bugFixOSVersion;

/*! Creation */

// Create an instance of SArtFile from an encoded SArtFile.bin
+ (SArtFile *)sArtFileWithFileAtURL:(NSURL *)url;
- (id)initWithFileAtURL:(NSURL *)url;

// Create an instance of SArtFile from an encoded SArtFile.bin
+ (SArtFile *)sArtFileWithFileAtURL:(NSURL *)url majorOS:(NSUInteger)major minorOS:(NSUInteger)minor bugFixOS:(NSUInteger)bugFix;
- (id)initWithFileAtURL:(NSURL *)url majorOS:(NSUInteger)major minorOS:(NSUInteger)minor bugFixOS:(NSUInteger)bugFix;

// Create an instance of SArtFile from a decoded folder
+ (SArtFile *)sartFileWithFolderAtURL:(NSURL *)folderURL;
- (id)initWithFolderAtURL:(NSURL *)folderURL;

/*! Operations */

// Encode the SArtFile instance to a path
- (BOOL)saveToFileAtURL:(NSURL *)url error:(NSError **)error;
// Decode the SArtFile instance to a folder
- (void)decodeToFolderAtURL:(NSURL *)folderURL error:(NSError **)error;

+ (NSURL *)sArtFilePath;

@end
