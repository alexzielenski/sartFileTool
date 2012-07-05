//
//  main.m
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

	int c;
	int option_index = 0;
	
	NSString *path1, *path2;
	
	static struct option long_options[] = {
		{"pdf",    no_argument,       0,  0  },
		{"os",     required_argument, 0,  0  },
		{"help",   required_argument, 0,  'h'},
		{0,        0,                 0,  0  }};
	
	while ((c = getopt_long(argc, (char *const*)argv, "e:d", long_options, &option_index)) != -1) {
		switch (c) {
			case 0: {
				switch (option_index) {
					case 0: // --pdf
						pdf = YES;
						break;
					case 1: {// --os
						
						NSString *os = [NSString stringWithUTF8String:optarg];
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
						
						break;
					}
					case 2: // help
						printf(help, NULL);
						return 1;
						break;
						break;
						
				}
				break;
			}
			case 'e': {
				encode = YES;
				
				optind--;
				
				const char *cp1 = NULL, *cp2 = NULL;
				
				for(; optind < argc && *argv[optind] != '-'; optind++){
					const char *opt = argv[optind];
					
					if (cp1 == NULL)
						cp1 = opt;
					else if (cp2 == NULL)
						cp2 = opt;
					else {
						NSLog(@"Something went wrong at option %s", opt);
						printf(help, NULL);
						return 1;
					}
				}
				
				path1 = [NSString stringWithUTF8String:cp1];
				path2 = [NSString stringWithUTF8String:cp2];
				
				break;
			}
			case 'd': {
				encode = NO;
				
				const char *cp1 = NULL, *cp2 = NULL;
				
				for(; optind < argc && *argv[optind] != '-'; optind++){
					const char *opt = argv[optind];
					
					if (cp1 == NULL)
						cp1 = opt;
					else if (cp2 == NULL)
						cp2 = opt;
					else {
						NSLog(@"Something went wrong at option %s", opt);
						printf(help, NULL);
						return 1;
					}
				}
				
				if (cp2 == NULL) {
					cp2 = cp1;
					cp1 = NULL;
				}
				
				if (cp1 != NULL)
					path1 = [NSString stringWithUTF8String:cp1];
				else
					path1 = [[SArtFile sArtFilePath] path];
				if (cp2 != NULL)
					path2 = [NSString stringWithUTF8String:cp2];
				else {
					NSLog(@"Something went horribly wrong.");
					printf(help, NULL);
					return 1;
				}
				
				break;
			}
			default:
				printf(help, NULL);
				return 1;
				break;
		}
	}

	if (!path1 || !path2) {
		printf("Missing arguments\n");
		printf(help, NULL);
		return 1;
	}
	
    path1 = [path1 stringByExpandingTildeInPath];
    path2 = [path2 stringByExpandingTildeInPath];

    printf("sartFileTool and reverse engineering by Alex Zielenski (http://alexzielenski.com)\n");
    
    @try {
#ifdef DEBUG
        uint64_t start = mach_absolute_time();
#endif
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
            
            if (majorOS != -1) {
                file.majorOSVersion  = majorOS;
                file.minorOSVersion  = minorOS;
                file.bugFixOSVersion = bugFixOS;
            }
            
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

