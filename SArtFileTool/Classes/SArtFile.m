//
//  SArtFile.m
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

#import "SArtFile.h"
#import "NSData+Byte.h"

@interface SArtFile ()
- (void)generateBuffersFromData:(NSData *)data;
@end

@implementation SArtFile
@synthesize header             = _header;
@synthesize shouldWritePDFReps = _shouldWritePDFReps;
@synthesize majorOSVersion     = _majorOSVersion;
@synthesize minorOSVersion     = _minorOSVersion;
@synthesize bugFixOSVersion    = _bugFixOSVersion;
@synthesize buffer1            = _buffer1;

#pragma mark - Lifecycle

+ (SArtFile *)sArtFileWithFileAtURL:(NSURL *)url
{
    return [[[self alloc] initWithFileAtURL:url] autorelease];
}

- (id)initWithFileAtURL:(NSURL *)url
{
    if ((self = [self init])) {
        NSData *fileData = [NSData dataWithContentsOfURL:url];
        
        if (!fileData) {
            NSLog(@"No data");
            [self release];
            return nil;
        }
        
        _header  = [[SFHeader headerWithData:fileData file:self] retain];
        _header.sartFile = self;
        
        [self generateBuffersFromData:fileData];

    }
    
    return self;
}

+ (SArtFile *)sArtFileWithFileAtURL:(NSURL *)url majorOS:(NSUInteger)major minorOS:(NSUInteger)minor bugFixOS:(NSUInteger)bugFix
{
    return [[[self alloc] initWithFileAtURL:url majorOS:major minorOS:minor bugFixOS:bugFix] autorelease];
}

- (id)initWithFileAtURL:(NSURL *)url majorOS:(NSUInteger)major minorOS:(NSUInteger)minor bugFixOS:(NSUInteger)bugFix
{
    if (major == -1) { // No OS
        return [self initWithFileAtURL:url];
    }
    
    if ((self = [self init])) {
                
        _majorOSVersion  = (int)major;
        _minorOSVersion  = (int)minor;
        _bugFixOSVersion = (int)bugFix;
        
        NSData *fileData = [NSData dataWithContentsOfURL:url];
        
        if (!fileData) {
            NSLog(@"No data");
            [self release];
            return nil;
        }
        
        _header = [[SFHeader headerWithData:fileData file:self] retain];
        _header.sartFile = self;
        
        [self generateBuffersFromData:fileData];
    }
    
    return self;
}

+ (SArtFile *)sartFileWithFolderAtURL:(NSURL *)folderURL
{
    return [[[self alloc] initWithFolderAtURL:folderURL] autorelease];
}

- (id)initWithFolderAtURL:(NSURL *)folderURL
{
    if ((self = [self init])) {
        // Process the receipt
        NSDictionary *receipt = [NSDictionary dictionaryWithContentsOfURL:[folderURL URLByAppendingPathComponent:@"_receipt.plist"]];
        _majorOSVersion     = [[receipt objectForKey:@"majorOS"] intValue];
        _minorOSVersion     = [[receipt objectForKey:@"minorOS"] intValue];
        _bugFixOSVersion    = [[receipt objectForKey:@"bugFixOS"] intValue];
                
        _buffer1            = [[receipt objectForKey:@"buffer1"] retain];
        _shouldWritePDFReps = [[receipt objectForKey:@"pdfsWritten"] boolValue];
        
        if ((_majorOSVersion != 10) || (_minorOSVersion <= 6)) {
            NSLog(@"Unsupported SArtFile OS Version: %ld.%ld.%ld", _majorOSVersion, _minorOSVersion, _bugFixOSVersion);
        }
        
        _header = [[SFHeader headerWithFolderURL:folderURL file:self] retain];
    }
    
    return self;
}

- (void)generateBuffersFromData:(NSData *)data
{
    // The first buffer is a group of unknown data between the descriptor offset list and the descriptors
    NSUInteger offsetLength = 8 + 4 * self.header.descriptors.count;
    NSUInteger firstDescriptorOffset = [data intAtOffset:8];
    
    NSUInteger buffer1Length = firstDescriptorOffset - offsetLength;
    
    if (buffer1Length > 0) {
        _buffer1 = [[data subdataWithRange:NSMakeRange(offsetLength, buffer1Length)] retain];
    }
    
}

+ (NSURL *)sArtFilePath
{
    return [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"];
}

- (id)init
{
    if ((self = [super init])) {
        // http://stackoverflow.com/questions/6492038/find-mac-os-x-version-number-in-objective-c
        SInt32 major, minor, bugfix;
        Gestalt(gestaltSystemVersionMajor, &major);
        Gestalt(gestaltSystemVersionMinor, &minor);
        Gestalt(gestaltSystemVersionBugFix, &bugfix);
        
        _majorOSVersion  = major;
        _minorOSVersion  = minor;
        _bugFixOSVersion = bugfix;
    }
    
    return self;
}

- (void)dealloc
{
    [_header release];
    self.buffer1 = nil;
    
    [super dealloc];
}

- (NSData *)sartFileData
{
    return self.header.headerData;
}

- (NSArray *)allImageRepresentations
{
    return [self.header valueForKeyPath:@"descriptors.@unionOfArrays.fileHeaders.imageRepresentation"];
}

#pragma mark - Operations

- (BOOL)saveToFileAtURL:(NSURL *)url error:(NSError **)error
{
    
    NSData *headerData = self.header.headerData;
    
    if (headerData)
        [headerData writeToURL:url atomically:NO];
    else {
        NSLog(@"No data?");
    }
    
    return YES;
}

- (void)decodeToFolderAtURL:(NSURL *)folderURL error:(NSError **)error
{
    NSLog(@"File Count: %d", self.header.fileCount);
    NSLog(@"Master Offset: %d", self.header.masterOffset);
    
    NSDictionary *receipt = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedInteger:self.majorOSVersion], @"majorOS",
                             [NSNumber numberWithUnsignedInteger:self.minorOSVersion], @"minorOS",
                             [NSNumber numberWithUnsignedInteger:self.bugFixOSVersion], @"bugFixOS",
                             [NSNumber numberWithBool:self.shouldWritePDFReps], @"pdfsWritten", 
                             self.buffer1, @"buffer1", nil];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:folderURL 
      withIntermediateDirectories:YES 
                       attributes:nil 
                            error:error];
    if (error) {
        return;
    }
    BOOL writeProperties = NO;
    
#ifdef DEBUG
    writeProperties = YES;
#endif
    
	NSMutableArray *deb = (writeProperties) ? [NSMutableArray array] : nil;
    
    for (SFDescriptor *descriptor in self.header.descriptors) {
        
		NSMutableDictionary *fd = writeProperties ? [NSMutableDictionary dictionary] : nil;
        
        if (writeProperties) {
            
            [fd setObject:[NSNumber numberWithUnsignedShort:descriptor.type] forKey:@"type"];
            [fd setObject:[NSNumber numberWithUnsignedShort:descriptor.fileHeaders.count] forKey:@"count"];
		
        }
        
		NSMutableArray *fh = writeProperties ? [NSMutableArray array] : nil;
		
        NSUInteger index = [self.header.descriptors indexOfObject:descriptor];
        BOOL pdf = descriptor.type == SFDescriptorTypePDF;
                
        for (SFFileHeader *header in descriptor.fileHeaders) {
            if (writeProperties) {
                [fh addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithUnsignedShort:header.width], @"width",
                               [NSNumber numberWithUnsignedShort:header.height], @"height",
                               [NSNumber numberWithUnsignedInt:header.length], @"length",
                               [NSNumber numberWithUnsignedInt:header.offset], @"offset",
                               [NSNumber numberWithUnsignedInt:self.header.masterOffset + header.offset], @"finalOffset", nil]];
            }
			
            NSInteger item = [descriptor.fileHeaders indexOfObject:header] + 1;
            
            if (!self.shouldWritePDFReps && item > 1 && pdf)
                continue;
            
            NSString *extension = (pdf && item == 1) ? @"pdf" : (descriptor.type == SFDescriptorTypeTIF) ?  @"tif" : @"png";
            
            NSString *fileName = [[NSString stringWithFormat:@"%ld-%ld", index, item] stringByAppendingPathExtension:extension];
            [header.imageData writeToURL:[folderURL URLByAppendingPathComponent:fileName] atomically:NO];
        }
        
        if (writeProperties) {
            [fd setObject:fh forKey:@"headers"];
            [deb addObject:fd];
        }
        
        NSLog(@"Decoded index %lu", index);
    }
	
    if (writeProperties)
        [deb writeToFile:[@"~/Desktop/debug.plist" stringByExpandingTildeInPath] atomically:NO];
    
    [receipt writeToURL:[folderURL URLByAppendingPathComponent:@"_receipt.plist"] atomically:NO];
}

@end
