//
//  NSImageRep+Data.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSPDFImageRep (DataAdditions)

@end

@interface NSImageRep (DataAdditions)

- (NSData *)sartFileData;

@end
