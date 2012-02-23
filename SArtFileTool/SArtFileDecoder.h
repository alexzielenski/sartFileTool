//
//  SArtFileDecoder.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/6/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//
#import <Foundation/Foundation.h>

struct file_header {
	uint16_t unknown; // Could be version?
	uint16_t artCount;
	uint32_t masterOffset;
};

struct file_descriptor {
	uint16_t type; // 1 is tiff. 2 is PNG. 3 is PDF
	uint16_t unknown; // Flags or a tag maybe. 1 means no retina resource.
	uint32_t unknown2; // This number is file_size - 45 (unused as of 10.8)
	uint32_t unknown3; // This number is unknown2 + legacyRep_file_size + retinaRep_file_size (unused as of 10.8)
	uint16_t image_width;
	uint16_t image_height;
	uint32_t file_size;
	uint32_t file_offset;
	
	//tiff,png only (mostly prominent in 10.7.2)
	uint16_t retina_width;
	uint16_t retina_height;
	uint32_t retina_file_size;
	uint32_t retina_file_offset;

	
	// pdf only
	uint16_t legacyRep_width; //png representation of the pdf
	uint16_t legacyRep_height;
	uint32_t legacyRep_file_size;
	uint32_t legacyRep_file_offset;
	uint16_t retinaRep_width;
	uint16_t retinaRep_height;
	uint32_t retinaRep_file_size;
	uint32_t retinaRep_file_offset;
};

void writeImagesToFolder(NSString *path, NSString *pathToSartFile);
void writeImage(int idx, NSString *path);
void writeImageData(CFDataRef data, CFURLRef path, uint16_t type, uint16_t width, uint16_t height);
static void readHeader(NSString *path);
static struct file_descriptor descForEntry(NSInteger idx);