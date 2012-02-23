//
//  SArtFileDecoder.c
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/6/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//

#import "Defines.h"
#include "SArtFileDecoder.h"

static NSData *sartFileData;
static int _masterOffset;
static short _artCount;
static NSMutableDictionary *dict;
static uint16_t readShortAt(NSUInteger offset) {
	uint16_t result;
	[sartFileData getBytes: &result range: NSMakeRange (offset, sizeof (result))];
	return CFSwapInt16LittleToHost (result);
}

static uint32_t readIntAt(NSUInteger offset) {
	uint32_t result;
	[sartFileData getBytes: &result range: NSMakeRange (offset, sizeof (result))];
	return CFSwapInt32LittleToHost (result);
}

static uint64_t readBigIntAt(NSUInteger offset) {
	uint64_t result;
	[sartFileData getBytes: &result range: NSMakeRange (offset, sizeof (result))];
	return CFSwapInt64LittleToHost (result);
}

static uint8_t readByteAt(NSUInteger offset) {
	uint8_t result;
	[sartFileData getBytes: &result range: NSMakeRange (offset, sizeof (result))];
	return result;
}

static void readHeader(NSString *path) {
	sartFileData = [[NSData dataWithContentsOfFile:path] retain];
	_artCount = readShortAt(2);
	_masterOffset = readIntAt(4);
}

static struct file_descriptor descForEntry(NSInteger idx) {
	struct file_descriptor fd;
	
	uint32_t offset = readIntAt(8 + sizeof(uint32_t) * idx);
	fd.type = readShortAt(offset);
	offset+=(int)sizeof(uint16_t);
	fd.unknown = readShortAt(offset);
	offset+=(int)sizeof(uint16_t);
	
	if (OSVersion < 0x108)
	{
		fd.unknown2 = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);
		fd.unknown3 = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);
	}
	
	fd.image_width = readShortAt(offset);
	offset+=(int)sizeof(uint16_t);
	fd.image_height = readShortAt(offset);
	offset+=(int)sizeof(uint16_t);
	fd.file_size = readIntAt(offset);
	offset+=(int)sizeof(uint32_t);
	fd.file_offset = readIntAt(offset);
	offset+=(int)sizeof(uint32_t);
	
	if (fd.type==3) { // pdfs have doubly sized headers
		fd.legacyRep_width = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.legacyRep_height = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.legacyRep_file_size = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);
		fd.legacyRep_file_offset = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);		
		
		// retina?
		fd.retinaRep_width = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.retinaRep_height = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.retinaRep_file_size = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);
		fd.retinaRep_file_offset = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);	
	} else if (fd.type==1 && fd.unknown!=1) {
		//retina
		fd.retina_width = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.retina_height = readShortAt(offset);
		offset+=(int)sizeof(uint16_t);
		fd.retina_file_size = readIntAt(offset);
		offset+=(int)sizeof(uint32_t);
		fd.retina_file_offset = readIntAt(offset);
	}
	return fd;
}

void writeImage(int idx, NSString *path) {
	struct file_descriptor fd = descForEntry(idx);
	
	uint16_t imageWidth = fd.image_width;
	uint16_t imageHeight = fd.image_height;
	uint32_t imageLength = fd.file_size;

	
	NSUInteger imageOffset = fd.file_offset + _masterOffset;
	NSData *imageData = [sartFileData subdataWithRange:NSMakeRange(imageOffset, imageLength)];
	
	if (fd.type!=3) {
		NSURL *imageURL = [NSURL fileURLWithPath:[path stringByAppendingPathComponent:[NSString stringWithFormat:@"%i.png", idx]]];
		
		writeImageData((CFDataRef)imageData, (CFURLRef)imageURL, fd.type, imageWidth, imageHeight);
		
	} else {
		[imageData writeToFile:[path stringByAppendingPathComponent:[NSString stringWithFormat:@"%i.pdf", idx]] atomically:NO];
	}
	
	if (fd.type==1 && fd.unknown!=1) {
		uint16_t retina_width = fd.retina_width;
		uint16_t retina_height = fd.retina_height;
		uint32_t retina_length = fd.retina_file_size;
		
		NSUInteger retinaOffset = fd.retina_file_offset + _masterOffset;
		NSURL *retinaURL = [NSURL fileURLWithPath:[path stringByAppendingPathComponent:[NSString stringWithFormat:@"%i@2x.png", idx]]];
		
		NSData *retinaImageData = [sartFileData subdataWithRange:NSMakeRange(retinaOffset, retina_length)];
		writeImageData((CFDataRef)retinaImageData, (CFURLRef)retinaURL, fd.type, retina_width, retina_height);
		
		
	}
//	uint32_t offset = readIntAt(8 + 4 * idx);
	
	/*
	NSMutableDictionary *f = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithInt:offset], @"offset",
							  [NSNumber numberWithShort:fd.type], @"00",
							  [NSNumber numberWithShort:fd.unknown], @"02",
							  [NSNumber numberWithInt:fd.unknown2], @"04",
							  [NSNumber numberWithInt:fd.unknown3], @"08",
							  [NSNumber numberWithShort:fd.image_width], @"12",
							  [NSNumber numberWithShort:fd.image_height], @"14",
							  [NSNumber numberWithInt:fd.file_size], @"16",
							  [NSNumber numberWithInt:fd.file_offset], @"20", nil];
	if (fd.type==3) { // extended header
		[f setObject:[NSNumber numberWithShort:readShortAt(offset+24)] forKey:@"24"]; // duplicated size width
		[f setObject:[NSNumber numberWithShort:readShortAt(offset+26)] forKey:@"26"]; // duplicated size height
		[f setObject:[NSNumber numberWithInt:readIntAt(offset+28)] forKey:@"28"]; // duplicated size width * height * 4 There is this about of null bytes +  the int at 40
		[f setObject:[NSNumber numberWithInt:readIntAt(offset+32)] forKey:@"32"]; // Offset when the 440 0x0000FF or null bytes stop
		[f setObject:[NSNumber numberWithShort:readShortAt(offset+36)] forKey:@"36"]; // width * 2
		[f setObject:[NSNumber numberWithShort:readShortAt(offset+38)] forKey:@"38"]; // height * 2
		[f setObject:[NSNumber numberWithInt:readIntAt(offset+40)] forKey:@"40"]; // width * 2 * height * 2 * 4
		[f setObject:[NSNumber numberWithInt:readIntAt(offset+44)] forKey:@"44"]; // offset when this new about of bytes stop
		
	} else {
		NSMutableDictionary *f1 = [[NSMutableDictionary alloc] init];
		[f1 setObject:[NSNumber numberWithShort:readShortAt(offset+24)] forKey:@"24"]; // duplicated size width
		[f1 setObject:[NSNumber numberWithShort:readShortAt(offset+26)] forKey:@"26"]; // duplicated size height
		[f1 setObject:[NSNumber numberWithInt:readIntAt(offset+28)] forKey:@"28"]; // duplicated size width * height * 4 There is this about of null bytes +  the int at 40
		[f1 setObject:[NSNumber numberWithInt:readIntAt(offset+32)] forKey:@"32"]; // Offset when the 440 0x0000FF or null bytes stop
		[f1 setObject:[NSNumber numberWithShort:readShortAt(offset+36)] forKey:@"36"]; // width * 2
		[f1 setObject:[NSNumber numberWithShort:readShortAt(offset+38)] forKey:@"38"]; // height * 2
		[f1 setObject:[NSNumber numberWithInt:readIntAt(offset+40)] forKey:@"40"]; // width * 2 * height * 2 * 4
		[f1 setObject:[NSNumber numberWithInt:readIntAt(offset+44)] forKey:@"44"]; // offset when this new about of bytes stop
		NSLog(@"%@", f);
		NSLog(@"%@", f1);
		[f1 release];
	}
	[dict setObject:f forKey:[[NSNumber numberWithInt:idx] stringValue]];*/

}
void writeImageData(CFDataRef data, CFURLRef path, uint16_t type, uint16_t width, uint16_t height) {
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo bitmapInfo = kCGImageAlphaFirst;
	if (OSVersion > 0x106)
		bitmapInfo |= kCGBitmapByteOrder32Little;
	
	CGImageRef cgImage = CGImageCreate(width, height, 8, 32, 4 * width, colorSpace, bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault);
	NSString *uti = @"public.png";
	CGImageDestinationRef dest = CGImageDestinationCreateWithURL(path, (CFStringRef)uti, 1, NULL);
	CGImageDestinationAddImage(dest, cgImage, NULL);
	CGImageDestinationFinalize(dest);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	CGImageRelease(cgImage);
	CFRelease(dest);
}
void writeImagesToFolder(NSString *path, NSString *pathToSartFile) {
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir;
	BOOL exists = [fm fileExistsAtPath:path 
						   isDirectory:&isDir];
	dict = [[NSMutableDictionary dictionary] retain];


	
	if (!exists) {
		[fm createDirectoryAtPath:path 
	  withIntermediateDirectories:YES
					   attributes:NO
							error:NO];
	} else if (!isDir) {
		printf("Error: Cannot write images to specified directory\n");
		return;
	}
	
	readHeader(pathToSartFile);
	
	printf("Art Count: %i\nMaster Offset: %i\n", _artCount, _masterOffset);

	for (int x = 0; x < _artCount; x++) {
		printf("Decoded Index : %i\n", x);
		writeImage(x, path);
	}
	
	if (sartFileData)
		[sartFileData release];
}