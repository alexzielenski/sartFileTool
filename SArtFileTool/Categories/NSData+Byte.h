//
//  NSData+Byte.h
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (ByteAdditions)

- (NSUInteger)currentOffset;
- (void)setCurrentOffset:(NSUInteger)offset;

- (uint8_t)nextByte;
- (uint8_t)byteAtOffset:(NSUInteger)offset;

- (uint16_t)nextShort;
- (uint16_t)shortAtOffset:(NSUInteger)offset;

- (uint32_t)nextInt;
- (uint32_t)intAtOffset:(NSUInteger)offset;

- (uint64_t)nextLong;
- (uint64_t)longAtOffset:(NSUInteger)offset;

@end

@interface NSMutableData (ByteAdditions)

- (void)appendByte:(uint8_t)value;
- (void)appendShort:(uint16_t)value;
- (void)appendInt:(uint32_t)value;
- (void)appendLong:(uint64_t)value;

@end