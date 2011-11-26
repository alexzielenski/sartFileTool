//
//  SartFileEncoder.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 6/6/11.
//  Copyright 2011 Alex Zielenski. All rights reserved.
//

void sartfile_encode(NSString *folder, NSString *originalPath, NSString *destPath);
unsigned char *bytesFromData(NSData *data, uint16_t *w, uint16_t *h);