//
//  SArtFile.h
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

#import <Foundation/Foundation.h>
#import "SFHeader.h"

// Objective-C class wrapper around the SArtFile.bin
@interface SArtFile : NSObject

@property (nonatomic, readonly) SFHeader *header;

@property (nonatomic, retain) NSData *buffer1;

// Options
@property (nonatomic, assign) BOOL shouldWritePDFReps;
@property (nonatomic, assign) NSUInteger  majorOSVersion;
@property (nonatomic, assign) NSUInteger  minorOSVersion;
@property (nonatomic, assign) NSUInteger  bugFixOSVersion;

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

- (NSData *)sartFileData;             // Final SArtFile data
- (NSArray *)allImageRepresentations; // Array of NSImageRep subclasses

@end
