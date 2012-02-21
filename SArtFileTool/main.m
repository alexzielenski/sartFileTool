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

// sysctl(3)
#include <sys/types.h>
#include <sys/sysctl.h>

#define __ENCODE__
#define __RELEASE__

int OSVersion;

static const char *help = "Usage:\n\tDecode: [-os 10.6|10.7|10.8] -d exportDirectory filePath\n\tEncode: -e imageDirectory originalFilePath newFilePath\n";
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
		if  ((!strcmp(argv[x], "-l"))) { // Obsolete option. Use -os instead.
			OSVersion = 0x106;
			continue;
		}
		else if  ((!strcmp(argv[x], "-os"))) {
			x += 1;
			
			if (x >= argc) {
				printf("Missing argument for -os option.");
				printf(help, NULL);
				return 1;
			}
			
			if  ((!strcmp(argv[x], "10.6"))) {
				OSVersion = 0x106;
			} else if ((!strcmp(argv[x], "10.7"))) {
				OSVersion = 0x107;
			} else if ((!strcmp(argv[x], "10.8"))) {
				OSVersion = 0x108;
			} else {
				printf("Unknown argument for -os option.");
				printf(help, NULL);
				return 1;
			}
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
	
	// Calculate the current os version if no option
	// has been specified by the user.
	if (OSVersion == 0)
	{
		int mib[2] = { CTL_KERN, KERN_OSRELEASE };
		size_t len;
		
		if (sysctl(mib, 2, NULL, &len, NULL, 0) == 0)
		{
			char *darwin_version = (char *)malloc(len);
			
			if (sysctl(mib, 2, darwin_version, &len, NULL, 0) == 0)
			{
				NSString *darwinVersion = [[NSString alloc] initWithUTF8String:darwin_version];
				NSString *majorVersionComponent = [[darwinVersion componentsSeparatedByString:@"."] objectAtIndex:0];
				
				unsigned long majorVersion = strtoul([majorVersionComponent UTF8String], NULL, 10);
				switch (majorVersion)
				{
					case 10:
						OSVersion = 0x106; // Snow
						break;
					case 11:
						OSVersion = 0x107; // Lion
						break;
					case 12:
					default:
						OSVersion = 0x108; // Mountain Lion
						break;
				}
				[darwinVersion release];
			}
			free(darwin_version);
		}
	}
	
	if (decode)
		printf("Decoding Files\n");
	if (encode)
		printf("Encoding Files\n");
	
	if (decode&&((argc==4)||(argc==5)||(argc==6))) {
		NSString *exportDir;
		NSString *file;
		
		file = [NSString stringWithUTF8String:argv[startIdx]];
		exportDir = [NSString stringWithUTF8String:argv[startIdx+1]];
        
		writeImagesToFolder(exportDir, file);
    } else if (encode&&((argc==5)||(argc==6)||(argc==7))) {
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

