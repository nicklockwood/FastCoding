//
//  FastCoding.m
//
//  Version 1.1
//
//  Created by Nick Lockwood on 09/12/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FastCoding
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "FastCoder.h"
#import <objc/runtime.h>


#import <Availability.h>
#if __has_feature(objc_arc)
#pragma GCC diagnostic ignored "-Wpedantic"
#warning FastCoding runs considerably slower under ARC. It is recommended that you disable it for this file
#endif


#pragma GCC diagnostic ignored "-Wgnu"
#pragma GCC diagnostic ignored "-Wpointer-arith"
#pragma GCC diagnostic ignored "-Wmissing-prototypes"
#pragma GCC diagnostic ignored "-Wfour-char-constants"


static const uint32_t FCIdentifier = 'FAST';
static const uint16_t FCMajorVersion = 1;
static const uint16_t FCMinorVersion = 0;


typedef struct
{
    uint32_t identifier;
    uint16_t majorVersion;
    uint16_t minorVersion;
}
FCHeader;


typedef NS_ENUM(uint32_t, FCType)
{
    FCTypeNull = 0,
    FCTypeAlias,
    FCTypeString,
    FCTypeDictionary,
    FCTypeArray,
    FCTypeSet,
    FCTypeOrderedSet,
    FCTypeTrue,
    FCTypeFalse,
    FCTypeInt32,
    FCTypeInt64,
    FCTypeFloat32,
    FCTypeFloat64,
    FCTypeData,
    FCTypeDate,
};


#if !__has_feature(objc_arc)
#define FC_AUTORELEASE(x) [(x) autorelease]
#else
#define FC_AUTORELEASE(x) (x)
#endif


#define FC_ASSERT_FITS(length, offset, total) { if ((NSUInteger)((offset) + (length)) > (total)) \
[NSException raise:NSInvalidArgumentException format:@"Unexpected EOF when parsing object starting at %i", (int32_t)(offset)]; }


#define FC_READ_VALUE(type, offset, input, total) type value; { \
FC_ASSERT_FITS (sizeof(type), offset, total); \
value = *(type *)(input + (offset)); offset += sizeof(value); }


@interface NSObject (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache;

@end


static inline uint32_t FCReadUInt32(NSUInteger *offset, const void *input, NSUInteger total)
{
    FC_READ_VALUE(uint32_t, *offset, input, total);
    return value;
}

id FCReadObject(NSUInteger *, const void *, NSUInteger, NSMutableArray *);

id FCReadNull(__unused NSUInteger *offset, __unused const void *input, __unused NSUInteger total, __unused NSMutableArray *cache) {
    return [NSNull null];
}

id FCReadAlias(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    return cache[FCReadUInt32(offset, input, total)];
}

id FCReadString(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    __autoreleasing NSString *string = nil;
    NSUInteger length = strlen(input + *offset) + 1;
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *offset, total);
    string = [[NSString alloc] initWithBytes:input + *offset length:length - 1 encoding:NSUTF8StringEncoding];
    *offset += paddedLength;
    [cache addObject:string];
    return FC_AUTORELEASE(string);
}

id FCReadDictionary(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    uint32_t count = FCReadUInt32(offset, input, total);
    __autoreleasing NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [dict setObject:FCReadObject(offset, input, total, cache) forKey:FCReadObject(offset, input, total, cache)];
    }
    return dict;
}

id FCReadArray(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    uint32_t count = FCReadUInt32(offset, input, total);
    __autoreleasing NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [array addObject:FCReadObject(offset, input, total, cache)];
    }
    return array;
}

id FCReadSet(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    uint32_t count = FCReadUInt32(offset, input, total);
    __autoreleasing NSMutableSet *set = [NSMutableSet setWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FCReadObject(offset, input, total, cache)];
    }
    return set;
}

id FCReadOrderedSet(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    uint32_t count = FCReadUInt32(offset, input, total);
    __autoreleasing NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FCReadObject(offset, input, total, cache)];
    }
    return set;
}

id FCReadTrue(__unused NSUInteger *offset, __unused const void *input, __unused NSUInteger total, __unused  NSMutableArray *cache) {
    return @YES;
}

id FCReadFalse(__unused NSUInteger *offset, __unused const void *input, __unused NSUInteger total, __unused  NSMutableArray *cache) {
    return @NO;
}

id FCReadInt32(NSUInteger *offset, const void *input, NSUInteger total, __unused NSMutableArray *cache) {
    FC_READ_VALUE(int32_t, *offset, input, total);
    return @(value);
}

id FCReadInt64(NSUInteger *offset, const void *input, NSUInteger total, __unused NSMutableArray *cache) {
    FC_READ_VALUE(int64_t, *offset, input, total);
    return @(value);
}

id FCReadFloat32(NSUInteger *offset, const void *input, NSUInteger total, __unused NSMutableArray *cache) {
    FC_READ_VALUE(Float32, *offset, input, total);
    return @(value);
}

id FCReadFloat64(NSUInteger *offset, const void *input, NSUInteger total, __unused NSMutableArray *cache) {
    FC_READ_VALUE(Float64, *offset, input, total);
    return @(value);
}

id FCReadData(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    uint32_t length = FCReadUInt32(offset, input, total);
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *offset, total);
    __autoreleasing NSData *data = [NSData dataWithBytes:(input + *offset) length:length];
    *offset += paddedLength;
    [cache addObject:data];
    return data;
}

id FCReadDate(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache) {
    FC_READ_VALUE(NSTimeInterval, *offset, input, total);
    __autoreleasing NSDate *date = [NSDate dateWithTimeIntervalSince1970:value];
    [cache addObject:date];
    return date;
}

id FCReadObject(NSUInteger *offset, const void *input, NSUInteger total, __unsafe_unretained NSMutableArray *cache)
{
    static id (*constructors[])(NSUInteger *, const void *, NSUInteger, id) =
    {
        FCReadNull,
        FCReadAlias,
        FCReadString,
        FCReadDictionary,
        FCReadArray,
        FCReadSet,
        FCReadOrderedSet,
        FCReadTrue,
        FCReadFalse,
        FCReadInt32,
        FCReadInt64,
        FCReadFloat32,
        FCReadFloat64,
        FCReadData,
        FCReadDate,
    };
    
    FCType type = FCReadUInt32(offset, input, total);
    if ((uint32_t)type > sizeof(constructors) / sizeof(id))
    {
        [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot decode object of type: %i", type];
        return nil;
    }
    return ((id (*)(NSUInteger *, const void *, NSUInteger, id))constructors[type])(offset, input, total, cache);
}

static inline void FCWriteUInt32(uint32_t value, __unsafe_unretained NSMutableData *output)
{
    [output appendBytes:&value length:sizeof(value)];
}

void FCWriteObject(id object, __unsafe_unretained NSMutableData *output, __unsafe_unretained NSMutableDictionary *cache)
{
    //check cache
    NSNumber *alias = cache[object];
    if (alias)
    {
        FCWriteUInt32(FCTypeAlias, output);
        FCWriteUInt32((uint32_t)[alias intValue], output);
    }
    else
    {
        [object FC_writeToOutput:output cache:cache];
    }
}


@implementation FastCoder

+ (id)objectWithData:(NSData *)data
{
    NSUInteger length = [data length];
    if (length < sizeof(FCHeader) + sizeof(FCType))
    {
        //not a valid FastArchive
        return nil;
    }
    
    const void *input = data.bytes;
    FCHeader header;
    memcpy(&header, input, sizeof(header));
    
    if (header.identifier != FCIdentifier)
    {
        //not a FastArchive
        return nil;
    }
    
    if (header.majorVersion > FCMajorVersion)
    {
        //not compatible
        NSLog(@"This version of the FastCoding library doesn't support FastCoding version %i files", header.majorVersion);
        return nil;
    }
    
    NSUInteger offset = sizeof(header);
    __autoreleasing NSMutableArray *known = [NSMutableArray array];
    return FCReadObject(&offset, input, length, known);
}

+ (NSData *)dataWithRootObject:(id)object
{
    if (object)
    {
        FCHeader header = {FCIdentifier, FCMajorVersion, FCMinorVersion};
        NSMutableData *output = [NSMutableData dataWithLength:sizeof(header)];
        memcpy(output.mutableBytes, &header, sizeof(header));
        __autoreleasing NSMutableDictionary *known = [NSMutableDictionary dictionary];
        FCWriteObject(object, output, known);
        return output;
    }
    return nil;
}

@end


@implementation NSObject (FastCoding)

- (void)FC_writeToOutput:(__unused NSMutableData *)output cache:(__unused NSMutableDictionary *)cache
{
    [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot encode objects of type: %@", [self class]];
}

@end


@implementation NSString (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeString, output);
    const char *string = [self UTF8String];
    NSUInteger length = strlen(string) + 1;
    [output appendBytes:string length:length];
    output.length += (4 - ((length % 4) ?: 4));
    cache[self] = @([cache count]);
}

@end


@implementation NSNumber (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unused NSMutableDictionary *)cache
{
    if (self == (void *)kCFBooleanFalse)
    {
        FCWriteUInt32(FCTypeFalse, output);
    }
    else if (self == (void *)kCFBooleanTrue)
    {
        FCWriteUInt32(FCTypeTrue, output);
    }
    else
    {
        CFNumberType subtype = CFNumberGetType((CFNumberRef)self);
        switch (subtype)
        {
            case kCFNumberSInt64Type:
            case kCFNumberLongLongType:
            case kCFNumberNSIntegerType:
            {
                int64_t value = [self longLongValue];
                if (value > (int64_t)INT32_MAX || value < (int64_t)INT32_MIN)
                {
                    FCWriteUInt32(FCTypeInt64, output);
                    [output appendBytes:&value length:sizeof(value)];
                    break;
                }
                //otherwise treat as 32-bit
            }
            case kCFNumberSInt8Type:
            case kCFNumberSInt16Type:
            case kCFNumberSInt32Type:
            case kCFNumberCharType:
            case kCFNumberShortType:
            case kCFNumberIntType:
            case kCFNumberLongType:
            case kCFNumberCFIndexType:
            {
                FCWriteUInt32(FCTypeInt32, output);
                int32_t value = (int32_t)[self intValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat32Type:
            case kCFNumberFloatType:
            {
                FCWriteUInt32(FCTypeFloat32, output);
                Float32 value = [self floatValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat64Type:
            case kCFNumberDoubleType:
            case kCFNumberCGFloatType:
            {
                FCWriteUInt32(FCTypeFloat64, output);
                Float64 value = [self floatValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
        }
    }
}

@end


@implementation NSDate (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeDate, output);
    NSTimeInterval value = [self timeIntervalSinceReferenceDate];
    [output appendBytes:&value length:sizeof(value)];
    cache[self] = @([cache count]);
}

@end


@implementation NSData (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeData, output);
    uint32_t length = (uint32_t)[self length];
    FCWriteUInt32(length, output);
    [output appendData:self];
    output.length += (4 - ((length % 4) ?: 4));
    cache[self] = @([cache count]);
}

@end


@implementation NSNull (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unused NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeNull, output);
}

@end


@implementation NSDictionary (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeDictionary, output);
    FCWriteUInt32((uint32_t)[self count], output);
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        FCWriteObject(obj, output, cache);
        FCWriteObject(key, output, cache);
    }];
}

@end


@implementation NSArray (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeArray, output);
    FCWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FCWriteObject(value, output, cache);
    }
}

@end


@implementation NSSet (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeSet, output);
    FCWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FCWriteObject(value, output, cache);
    }
}

@end


@implementation NSOrderedSet (FastCoding)

- (void)FC_writeToOutput:(__unsafe_unretained NSMutableData *)output cache:(__unsafe_unretained NSMutableDictionary *)cache
{
    FCWriteUInt32(FCTypeOrderedSet, output);
    FCWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FCWriteObject(value, output, cache);
    }
}

@end
