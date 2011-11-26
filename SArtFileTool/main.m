//
//  main.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/5/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//

#include "Defines.h"
#include "SArtFileDecoder.h"
#include "SartFileEncoder.h"
#import <Cocoa/Cocoa.h>

#define __ENCODE__
#define __RELEASE__

BOOL legacy;
static const char *help = "Usage:\n\tDecode: -d [-l] exportDirectory filePath\n\tEncode: -e [-l] imageDirectory originalFilePath newFilePath\n";
int main (int argc, const char * argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	// for debug
#if !defined (__RELEASE__)
#if defined (__ENCODE__)
	argc=5;
	argv[1]="-e";
	argv[2]="/Users/Alex/Desktop/mine";
	argv[3]="/Users/Alex/Desktop/SArtFile.orig.bin";
	argv[4]="/Users/Alex/Desktop/SArtFile.new.bin";
#else
	argc=4;
	argv[1]="-d";
	argv[2]="/Users/Alex/Desktop/mine";
	argv[3]="/Users/Alex/Desktop/SArtFile.orig.bin";
#endif
#endif
	
	BOOL decode = NO;
	BOOL encode = NO;
	
	int startIdx = 0;
	for (int x = 1; x < argc; x++) {
		if ((!strcmp(argv[x], "-l"))) {
			legacy = YES;
			continue;
		} else if  ((!strcmp(argv[x], "-d"))) {
			decode = YES;
			encode = NO;
			continue;
		} else if  ((!strcmp(argv[x], "-e"))) {
			encode = YES;
			decode = NO;
			continue;
		} else {
			startIdx = x;
			break;
		}
	}
	
	if (legacy)
		printf("Using legacy mode…\n");
	if (decode)
		printf("Decoding Files\n");
	if (encode)
		printf("Encoding Files\n");
	
	if (decode&&(argc==4||argc==5)) {
		NSString *exportDir;
		NSString *file;
		
		file = [NSString stringWithUTF8String:argv[startIdx]];
		exportDir = [NSString stringWithUTF8String:argv[startIdx+1]];
        
		writeImagesToFolder(exportDir, file);
    } else if (encode&&(argc==5||argc==6)) {
		NSString *dir;
		NSString *file;
		NSString *dest;
		
		dir = [NSString stringWithUTF8String:argv[startIdx]];
		file = [NSString stringWithUTF8String:argv[startIdx+1]];
		dest = [NSString stringWithUTF8String:argv[startIdx+2]];
		
		sartfile_encode(dir, file, dest);
    } else { // invalid first argument
        printf(help, NULL);
        [pool drain];
        return 1;
    }	

	
	[pool drain];
    return 0;
}

