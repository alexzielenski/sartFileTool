//
//  NSData+ByteAdditions.m
//  SArtFileTool
//
//  Created by Alex Zielenski on 5/17/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "NSData+Byte.h"
#import <objc/runtime.h>

@implementation NSData (ByteAdditions)

static char OFFSET;
- (NSUInteger)currentOffset
{
    NSNumber *value = objc_getAssociatedObject(self, &OFFSET);
    return value.unsignedIntegerValue;
}

- (void)setCurrentOffset:(NSUInteger)offset
{
    [self willChangeValueForKey:@"currentOffset"];
    objc_setAssociatedObject(self, &OFFSET, [NSNumber numberWithUnsignedInteger:offset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"currentOffset"];
}

- (uint8_t)nextByte
{
    return [self byteAtOffset:self.currentOffset];
}

- (uint8_t)byteAtOffset:(NSUInteger)offset
{
    uint8_t result;
    [self getBytes:&result range:NSMakeRange(offset, sizeof(result))];
    self.currentOffset = offset + sizeof(uint8_t);
    return result;
}

- (uint16_t)nextShort
{
    return [self shortAtOffset:self.currentOffset];
}

- (uint16_t)shortAtOffset:(NSUInteger)offset
{
    uint16_t result;
    [self getBytes:&result range:NSMakeRange(offset, sizeof(result))];
    self.currentOffset = offset + sizeof(result);
    return CFSwapInt16LittleToHost(result);
}

- (uint32_t)nextInt
{
    return [self intAtOffset:self.currentOffset];
}

- (uint32_t)intAtOffset:(NSUInteger)offset
{
    uint32_t result;
    [self getBytes:&result range:NSMakeRange(offset, sizeof(result))];
    self.currentOffset = offset + sizeof(result);
    return CFSwapInt32LittleToHost(result);
}

- (uint64_t)nextLong
{
    return [self longAtOffset:self.currentOffset];
}

- (uint64_t)longAtOffset:(NSUInteger)offset;
{
    uint64_t result;
    [self getBytes:&result range:NSMakeRange(offset, sizeof(result))];
    self.currentOffset = offset + sizeof(result);
    return CFSwapInt64LittleToHost(result);
}

@end
