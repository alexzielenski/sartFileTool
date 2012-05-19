//
//  SFHeader.m
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

#import "SFHeader.h"
#import "NSData+Byte.h"

@implementation SFHeader
@synthesize version      = _version;
@synthesize fileCount    = _fileCount;
@synthesize masterOffset = _masterOffset;
@synthesize descriptors  = _descriptors;
@synthesize sartFile     = _sartFile;

+ (SFHeader *)headerWithData:(NSData *)data
{
    return [[[self alloc] initWithData:data] autorelease];
}

- (id)initWithData:(NSData *)data
{
    if ((self = [self init])) {
        if (![_descriptors isKindOfClass:[NSMutableArray class]])
            _descriptors = [[NSMutableArray array] retain];
        
        data.currentOffset = 0;

        _version      = [data nextShort];
        _fileCount    = [data nextShort];
        _masterOffset = [data nextInt];
        
        NSMutableArray *descriptors = (NSMutableArray *)_descriptors;

        for (int x = 0; x < _fileCount; x++) {
            
            uint32_t headerOffset = [data intAtOffset:8 + sizeof(uint32_t) * x];
            
            data.currentOffset = headerOffset;
            
            SFDescriptor *descriptor = [SFDescriptor descriptorWithData:data header:self];
            [descriptors addObject:descriptor];
        }
    }
    
    return self;
}

+ (SFHeader *)headerWithFolderURL:(NSURL *)url file:(SArtFile *)file
{
    return [[[self alloc] initWithFolderURL:url file:file] autorelease];
}

- (id)initWithFolderURL:(NSURL *)url file:(SArtFile *)file
{
    if ((self = [self init])) {
        NSFileManager *manager = [NSFileManager defaultManager];
        BOOL exists, isDir;
        
        exists = [manager fileExistsAtPath:url.path isDirectory:&isDir];
        
        if (!exists || !isDir) {
            NSLog(@"Invalid directory specified");
            [self release];
            return nil;
        }
        
        NSError *err      = nil;
        NSArray *contents = [manager contentsOfDirectoryAtPath:url.path error:&err];
        
        if (err) {
            NSLog(@"%@", err.localizedFailureReason ? err.localizedFailureReason : err.localizedDescription);
            [self release];
            return nil;
        }
        
        // Sort alphabetically/numerically
        contents = [contents sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
             return [obj1 compare:obj2 options:NSNumericSearch]; 
        }];
    
        // Now that it is sorted numerically we can just pull the last item for its index
        NSString *lastItem = [contents objectAtIndex:contents.count - 2];
        NSArray *delimited = [lastItem componentsSeparatedByString:@"-"];
                
        if (delimited.count != 2) {
            // Shit
            NSLog(@"Error: make sure the directory contains nothing other than the receipt and the images");
            [self release];
            return nil;
        }
        
        for (NSString *fileName in contents) {
            if ([fileName isEqualToString:@"_receipt.plist"])
                continue;
            
            if (fileName.length <= 2) // At least 3 characters long
                continue;
            
            NSURL *fullPath = [url URLByAppendingPathComponent:fileName];
            NSArray *separation = [fileName componentsSeparatedByString:@"-"];
            
            if (separation.count <= 1) // Invalid file
                continue;
            
            SFDescriptor *desc = nil;
            NSUInteger index = [[separation objectAtIndex:0] intValue];
            
            if (self.descriptors.count > index) {
                desc = [self.descriptors objectAtIndex:index];
                
            } else {                
                desc = [SFDescriptor descriptor];
                desc.header = self;
                [self.descriptors addObject:desc];
            }
            
            [desc addFileAtURL:fullPath];
        }
        
        _fileCount = _descriptors.count;
    }
    
    return self;
}

- (id)init
{
    if ((self = [super init])) {
        _descriptors = [[NSMutableArray array] retain];
        _version   = 2;
        _fileCount = 348;
    }
    
    return self;
}

- (NSData *)headerData
{
    // version, file count, master offset, header offsets
    NSUInteger headerLength = 8;
    NSUInteger descOffsetLength = 4 * self.descriptors.count;
    NSUInteger totalLength =  headerLength + descOffsetLength;
    
    NSUInteger totalHeaderLength = [[self.descriptors valueForKeyPath:@"@sum.expectedLength"] unsignedIntegerValue];
        
    self.masterOffset = totalLength + totalHeaderLength;
    
    uint16_t version = CFSwapInt16HostToLittle(self.version);
    uint16_t count   = CFSwapInt16HostToLittle(self.fileCount);
    uint32_t offset  = CFSwapInt32HostToLittle(self.masterOffset);
    
    NSMutableData *headerData         = [NSMutableData dataWithCapacity:totalLength];
    NSMutableData *descriptorOffsets  = [NSMutableData dataWithCapacity:descOffsetLength];
    NSMutableData *descriptorHeaders  = [NSMutableData data];
    NSMutableData *fileData           = [NSMutableData data];
    
    for (SFDescriptor *desc in self.descriptors) {
        uint32_t descOffset = CFSwapInt32HostToLittle(totalLength + descriptorHeaders.length);
        
        [descriptorOffsets appendBytes:&descOffset length:sizeof(descOffset)];
        
        // Set the file offsets for its files before getting the header data
        for (SFFileHeader *fileHeader in desc.fileHeaders) {
            fileHeader.offset = fileData.length;            
            [fileData appendData:fileHeader.sartFileData];
        }
        
        [descriptorHeaders appendData:desc.headerData];  
        NSLog(@"Encoded index: %lu", [self.descriptors indexOfObject:desc]);
    }
    
    
    [headerData appendBytes:&version length:sizeof(uint16_t)];
    [headerData appendBytes:&count length:sizeof(uint16_t)];
    [headerData appendBytes:&offset length:sizeof(uint32_t)];
    
    [headerData appendData:descriptorOffsets];
    [headerData appendData:descriptorHeaders];
    [headerData appendData:fileData];
    
    return headerData;
}

@end
