//
//  main.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/5/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SArtFile.h"
#include <mach/mach_time.h>
#include <getopt.h>

static const char *help = "Usage:\n\tDecode: [-os 10.7|10.8|10.7.4|etc] -d [filePath] exportDirectory\n\tEncode: -e imageDirectory newFilePath\n";
int main (int argc, const char * argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    if (argc <= 2) {
        printf(help, NULL);
        return 1;
    }
    
    BOOL encode;
    BOOL pdf;
    
    int majorOS  = -1;
    int minorOS  = 0;
    int bugFixOS = 0;

	int startIdx = 0;
	for (int x = 1; x < argc; x++) {
		if ((!strcmp(argv[x], "-os"))) {
            NSString *os = [NSString stringWithUTF8String:argv[x]];
            NSArray *delimited = [os componentsSeparatedByString:@"."];
            
            for (int idx = 0; idx < delimited.count; idx++) {
                NSNumber *num = [delimited objectAtIndex:idx];
                int vers = num.intValue;
                
                if (idx == 0)
                    majorOS = vers;
                else if (idx == 1)
                    minorOS = vers;
                else if (idx == 2)
                    bugFixOS = vers;
                
            }
            
			continue;
		} else if  ((!strcmp(argv[x], "-d"))) {
			encode = NO;
			continue;
		} else if  ((!strcmp(argv[x], "-e"))) {
			encode = YES;
			continue;
        } else if ((!strcmp(argv[x], "-h")) || (!strcmp(argv[x], "-help")) || (!strcmp(argv[x], "?"))) {
            printf(help, NULL);
            return 1;
            break;
        } else if ((!strcmp(argv[x], "-pdf"))) { // hidden option
            
            pdf = YES;
            
		} else {
			startIdx = x;
			break;
		}
	}
    
    NSString *path1 = nil, *path2 = nil;
    
    if (argc -1 <= startIdx) {
        
        if (!encode) {
            path1 = [[SArtFile sArtFilePath] path];
            startIdx--;
            
        } else {
            NSLog(@"Missing arguments");
            printf(help, NULL);
            return 1;
        }
    }
    
    if (!path1)
        path1 = [NSString stringWithUTF8String:argv[startIdx]];
    
    path2 = [NSString stringWithUTF8String:argv[startIdx + 1]];
    
    @try {
        uint64_t start = mach_absolute_time();
       
        
        SArtFile *file = nil;
        if (!encode) {
            file = [SArtFile sArtFileWithFileAtURL:[NSURL fileURLWithPath:path1]
                                           majorOS:majorOS 
                                           minorOS:minorOS
                                          bugFixOS:bugFixOS];
            file.shouldWritePDFReps = pdf;
            
            [file decodeToFolderAtURL:[NSURL fileURLWithPath:path2] error:nil];
        } else {
            file = [SArtFile sartFileWithFolderAtURL:[NSURL fileURLWithPath:path1]];
            
            file.majorOSVersion  = majorOS;
            file.minorOSVersion  = minorOS;
            file.bugFixOSVersion = bugFixOS;
            
            file.shouldWritePDFReps = pdf;
            
            [file saveToFileAtURL:[NSURL fileURLWithPath:path2] error:nil];
        }
        
        // Thanks Cocoa Samurai http://cocoasamurai.blogspot.com/2006/12/tip-when-you-must-be-precise-be-mach.html
#ifdef DEBUG
        uint64_t end = mach_absolute_time(); 
        uint64_t elapsed = end - start; mach_timebase_info_data_t info; 
        mach_timebase_info(&info); 
        uint64_t nanoSeconds = elapsed * info.numer / info.denom; 
        printf ("elapsed time was %lld nanoseconds\n", nanoSeconds);
#endif
        
    } @catch (NSException *e) {
        NSLog(@"Something bad happened: %@ : %@", e.name, e.reason);
    }
        
	[pool drain];
    
    return 0;
}

