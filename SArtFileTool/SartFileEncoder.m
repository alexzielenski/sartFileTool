//
//  SartFileEncoder.c
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/6/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "Defines.h"
#include "SartFileEncoder.h"
#include "SArtFileDecoder.h"

static NSMutableData *sartFileData;

static struct file_header header;

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
	header.unknown=readShortAt(0);
	header.artCount=readShortAt(2);
	header.masterOffset = readIntAt(4);
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
	} else if (fd.type==1) {
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

unsigned char* bytesFromData(NSData *data, uint16_t *w, uint16_t *h) {
    // Create a bitmap from the source image data
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
    NSInteger width = [imageRep pixelsWide];
    NSInteger height = [imageRep pixelsHigh];
    if (w != NULL) { *w = (uint16_t)width; }
    if (h != NULL) { *h = (uint16_t)height; }
    
    unsigned char *bytes = [imageRep bitmapData];
    for (NSUInteger y = 0; y < width * height * 4; y += 4) { // bgra little endian + alpha first
		uint8_t a, r, g, b;
		
		if (imageRep.bitmapFormat & NSAlphaFirstBitmapFormat) {
			a = bytes[y];
			r = bytes[y+1];
			g = bytes[y+2];
			b = bytes[y+3];
		} else {
			r = bytes[y+0];
			g = bytes[y+1];
			b = bytes[y+2];
			a = bytes[y+3];
		}
		
		float factor = 255.0f/a;
		// unpremultiply alpha if there is any
		if (a > 0) {
			if (!(imageRep.bitmapFormat & NSAlphaNonpremultipliedBitmapFormat)) {
				b *= factor;
				g *= factor;
				r *= factor;
			}
		} else {
			b = 0;
			g = 0;
			r = 0;
		}
		
		if (OSVersion > 0x106) {
			bytes[y]=b;
			bytes[y+1]=g;
			bytes[y+2]=r;
			bytes[y+3]=a;
		} else {
			bytes[y]=a;
			bytes[y+1]=r;
			bytes[y+2]=g;
			bytes[y+3]=b;
		}
	}
    return bytes;
}

void sartfile_encode(NSString *folder, NSString *originalPath, NSString *destPath) {
	readHeader(originalPath);

	printf("Art Count: %i\nMaster Offset: %i\n", header.artCount, header.masterOffset);
		
	NSMutableData *entire=[[NSMutableData alloc] initWithCapacity:header.masterOffset];
	[entire appendData:[sartFileData subdataWithRange:NSMakeRange(0, header.masterOffset)]];
	NSMutableData *data = [[NSMutableData alloc] initWithCapacity:0];
	
	for (int x = 0; x < header.artCount; x++) {
		struct file_descriptor fd = descForEntry(x);
		uint32_t base_offset = readIntAt(8 + sizeof(uint32_t) * x);
		uint32_t offset = base_offset;
		
		NSData *origImageData = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%i.%@", x, ((fd.type!=3) ? @"png" : @"pdf")]]];
		NSData *retinaImageData = nil;
		if (fd.type==1) {
		 	//we have retina
			retinaImageData = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%i@2x.png", x]]];
		}
		
		unsigned char *bytes;
		unsigned char *retina_bytes;
		
		uint16_t width = 0;
		uint16_t height = 0;
		uint16_t retina_width = 0;
		uint16_t retina_height = 0;
		uint32_t filesize;
		uint32_t retina_filesize;
		
		if (fd.type!=3) {
			bytes = bytesFromData(origImageData, &width, &height);
			filesize=4*height*width;
			
			if (fd.type==1) {
				retina_bytes = bytesFromData(retinaImageData, &retina_width, &retina_height);
				retina_filesize=4*retina_width*retina_height;
			}
			
		} else if (fd.type==3) {
			NSPDFImageRep *pdf = [NSPDFImageRep imageRepWithData:origImageData];
			width=pdf.bounds.size.width;
			height=pdf.bounds.size.height;
			filesize=(uint32_t)[origImageData length];
			bytes = (unsigned char*)[origImageData bytes];
		}
		
		fd.file_size=CFSwapInt32HostToLittle(filesize);		
		fd.file_offset=CFSwapInt32HostToLittle((uint32_t)[data length]);
		fd.image_width=CFSwapInt16HostToLittle((uint16_t)width);
		fd.image_height=CFSwapInt16HostToLittle((uint16_t)height);
		fd.type=CFSwapInt16HostToLittle(fd.type);
		fd.unknown=CFSwapInt16HostToLittle(fd.unknown);
		
		if (OSVersion < 0x108)
		{
			fd.unknown2=CFSwapInt32HostToLittle(fd.unknown2);
			fd.unknown3=CFSwapInt32HostToLittle(fd.unknown3);		
		}
		
		// extended pdf header
		if (fd.type==3) {
			fd.legacyRep_file_size = CFSwapInt32HostToLittle(fd.image_width*fd.image_height*4);
			fd.legacyRep_file_offset = CFSwapInt32HostToLittle(fd.file_offset+fd.file_size);
			fd.legacyRep_width= CFSwapInt16HostToLittle(fd.image_width);
			fd.legacyRep_height = CFSwapInt16HostToLittle(fd.image_height);
			fd.retinaRep_width = CFSwapInt16HostToLittle(fd.legacyRep_width*2);
			fd.retinaRep_height = CFSwapInt16HostToLittle(fd.legacyRep_height*2);
			fd.retinaRep_file_size = CFSwapInt32HostToLittle(fd.legacyRep_height*fd.legacyRep_width*4*4);
			fd.retinaRep_file_offset = CFSwapInt32HostToLittle(fd.legacyRep_file_offset+fd.legacyRep_file_size);
		} else if (fd.type==1) {
		 	fd.retina_width=CFSwapInt16HostToLittle(retina_width);
			fd.retina_height=CFSwapInt16HostToLittle(retina_height);
			fd.retina_file_size=CFSwapInt32HostToLittle(retina_filesize);
			fd.retina_file_offset=CFSwapInt32HostToLittle(fd.file_size+fd.file_offset);
		}
		
		
		[entire replaceBytesInRange:NSMakeRange(offset, 2) 
						   withBytes:&fd.type];
		offset += 2;
		[entire replaceBytesInRange:NSMakeRange(offset, 2) 
						  withBytes:&fd.unknown];
		offset += 2;
		
		if (OSVersion < 0x108)
		{
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.unknown2];
			offset += 4;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.unknown3];
			offset += 4;
		}
		
		[entire replaceBytesInRange:NSMakeRange(offset, 2) 
						  withBytes:&fd.image_width];
		offset += 2;
		[entire replaceBytesInRange:NSMakeRange(offset, 2) 
						  withBytes:&fd.image_height];
		offset += 2;
		[entire replaceBytesInRange:NSMakeRange(offset, 4) 
						  withBytes:&fd.file_size];
		offset += 4;
		[entire replaceBytesInRange:NSMakeRange(offset, 4)
						  withBytes:&fd.file_offset];
		offset += 4;

		if (fd.type==3) {
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.legacyRep_width];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.legacyRep_height];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.legacyRep_file_size];
			offset += 4;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.legacyRep_file_offset];
			offset += 4;
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.retinaRep_width];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.retinaRep_height];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.retinaRep_file_size];
			offset += 4;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.retinaRep_file_offset];
			offset += 4;
		} else if (fd.type==1) {
			// for @2X
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.retina_width];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 2) 
							  withBytes:&fd.retina_height];
			offset += 2;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.retina_file_size];
			offset += 4;
			[entire replaceBytesInRange:NSMakeRange(offset, 4) 
							  withBytes:&fd.retina_file_offset];
			offset += 4;

		} 
		
		NSData *imageData = [NSData dataWithBytesNoCopy:bytes 
												 length:(NSUInteger)filesize 
										   freeWhenDone:NO];
		[data appendData:imageData];
		
		if (fd.type==1) {
			
			// put in retina image
			imageData = [NSData dataWithBytesNoCopy:retina_bytes 
											 length:(NSUInteger)retina_filesize 
									   freeWhenDone:NO];
			[data appendData:imageData];

		}

		
		// put in the png reps
		if (fd.type==3) {
			NSImage *img = [[NSImage alloc] initWithData:origImageData];
			[img setScalesWhenResized:YES];
			[img setSize:NSMakeSize(width, height)];
			
			NSData *tempData = [img TIFFRepresentation];
			unsigned char *h = bytesFromData(tempData, NULL, NULL);
			tempData = [NSData dataWithBytes:h length:4*width*height];
			
			[data appendData:tempData];
			
			NSImage *tempImage = [[NSImage alloc] initWithSize:NSMakeSize(width*2, height*2)];
			[tempImage lockFocus];
			[img drawInRect:NSMakeRect(0, 0, 
									   width*2, height*2)
				   fromRect:NSZeroRect 
				  operation:NSCompositeSourceOver
				   fraction:1.0];
			[tempImage unlockFocus];
			
			tempData=[tempImage TIFFRepresentation];
			
			h = bytesFromData(tempData, NULL, NULL);
			tempData = [NSData dataWithBytes:h length:4*4*width*height];
			[img release];
			[tempImage release];
			
			[data appendData:tempData];
		}
	
		
		printf("Encoded Index : %i\nHeader Offset : %i\n", x, base_offset);
	
	}
	
	[entire appendData:data];
	[entire writeToFile:destPath atomically:NO];
	
	
	[data release];
	[entire release];
	
	if (sartFileData)
		[sartFileData release];
}