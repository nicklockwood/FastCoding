//
//  FastCoding.m
//
//  Version 1.0.1
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
#warning FastCoding runs considerably slower under ARC. It is recommended that you disable it for this file
#endif


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


@interface NSObject (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache;
+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache;

@end


@interface FCAlias : NSObject

@end


@implementation FastCoder

static inline uint32_t FastCodingReadUInt32(NSUInteger *offset, const void *input)
{
    uint32_t value = *(typeof(value) *)(input + *offset);
    *offset += sizeof(value);
    return value;
}

static inline void FastCodingWriteUInt32(uint32_t value, NSMutableData *output)
{
    [output appendBytes:&value length:sizeof(value)];
}

void FastCodingWriteObject(id object, NSMutableData *output, NSMutableDictionary *cache)
{
    //check cache
    NSNumber *alias = cache[object];
    if (alias)
    {
        FastCodingWriteUInt32(FCTypeAlias, output);
        FastCodingWriteUInt32((int32_t)[alias intValue], output);
    }
    else
    {
        [object FC_writeToOutput:output cache:cache];
    }
}

id FastCodingReadObject(NSUInteger *offset, const void *input, NSUInteger total, NSMutableArray *cache)
{
    static id classesByType[16];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classesByType[FCTypeNull] = [NSNull null];
        classesByType[FCTypeAlias] = [FCAlias class];
        classesByType[FCTypeString] = [NSString class];
        classesByType[FCTypeDictionary] = [NSDictionary class];
        classesByType[FCTypeArray] = [NSArray class];
        classesByType[FCTypeSet] = [NSSet class];
        classesByType[FCTypeOrderedSet] = [NSOrderedSet class];
        classesByType[FCTypeTrue] = @YES;
        classesByType[FCTypeFalse] = @NO;
        classesByType[FCTypeInt32] = [NSNumber class];
        classesByType[FCTypeInt64] = [NSNumber class];
        classesByType[FCTypeFloat32] = [NSNumber class];
        classesByType[FCTypeFloat64] = [NSNumber class];
        classesByType[FCTypeData] = [NSData class];
        classesByType[FCTypeDate] = [NSDate class];
    });
    
    FCType type = (FCType)FastCodingReadUInt32(offset, input);
    return [classesByType[type] instanceWithType:type offset:offset input:input total:total cache:cache];
}

+ (id)objectWithData:(NSData *)data
{
    NSUInteger length = [data length];
    if (length < 12)
    {
        //not a FastArchive
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
    NSMutableArray *known = [NSMutableArray array];
    return FastCodingReadObject(&offset, input, length, known);
}

+ (NSData *)dataWithRootObject:(id)object
{
    if (object)
    {
        FCHeader header = {FCIdentifier, FCMajorVersion, FCMinorVersion};
        NSMutableData *output = [NSMutableData dataWithLength:sizeof(header)];
        memcpy(output.mutableBytes, &header, sizeof(header));
        NSMutableDictionary *known = [NSMutableDictionary dictionary];
        FastCodingWriteObject(object, output, known);
        return output;
    }
    return nil;
}

@end


@implementation NSObject (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot encode objects of type: %@", [self class]];
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    //unsupported type
    char code[5] = {(type & 0xFF000000) >> 24, (type & 0x00FF0000) >> 16, (type & 0x0000FF00) >> 8, type & 0x000000FF, 0};
    [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot decode objects of type: %s", code];
    return nil;
}

@end


@implementation FCAlias

+ (id)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    return cache[FastCodingReadUInt32(offset, input)];
}

@end


@implementation NSString (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeString, output);
    const char *string = [self UTF8String];
    NSUInteger length = strlen(string) + 1;
    [output appendBytes:string length:length];
    output.length += (4 - ((length % 4) ?: 4));
    cache[self] = @([cache count]);
}
    
+ (id)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    NSString *string = nil;
    NSUInteger length = strlen(input + *offset) + 1;
    if ((NSUInteger)(*offset + length) > total)
    {
        [NSException raise:NSInvalidArgumentException format:@"Unterminated UTF8 string at location %i", (int32_t)*offset];
    }
    string = [NSString stringWithUTF8String:input + *offset];
    *offset += length + (4 - ((length % 4) ?: 4));
    [cache addObject:string];
    return string;
}

@end


@implementation NSNumber (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    if (self == (void *)kCFBooleanFalse)
    {
        FastCodingWriteUInt32(FCTypeFalse, output);
    }
    else if (self == (void *)kCFBooleanTrue)
    {
        FastCodingWriteUInt32(FCTypeTrue, output);
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
                    FastCodingWriteUInt32(FCTypeInt64, output);
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
                FastCodingWriteUInt32(FCTypeInt32, output);
                int32_t value = (int32_t)[self intValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat32Type:
            case kCFNumberFloatType:
            {
                FastCodingWriteUInt32(FCTypeFloat32, output);
                Float32 value = [self floatValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat64Type:
            case kCFNumberDoubleType:
            case kCFNumberCGFloatType:
            {
                FastCodingWriteUInt32(FCTypeFloat64, output);
                Float64 value = [self floatValue];
                [output appendBytes:&value length:sizeof(value)];
                break;
            }
        }
    }
}

- (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    return self;
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    switch (type)
    {
        case FCTypeInt32:
        {
            int32_t value = *(typeof(value) *)(input + *offset);
            *offset += sizeof(value);
            return @(value);
        }
        case FCTypeInt64:
        {
            int64_t value = *(typeof(value) *)(input + *offset);
            *offset += sizeof(value);
            return @(value);
        }
        case FCTypeFloat32:
        {
            Float32 value = *(typeof(value) *)(input + *offset);
            *offset += sizeof(value);
            return @(value);
        }
        case FCTypeFloat64:
        {
            Float64 value = *(typeof(value) *)(input + *offset);
            *offset += sizeof(value);
            return @(value);
        }
        default:
        {
            return nil;
        }
    }
}

@end


@implementation NSDate (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeDate, output);
    NSTimeInterval value = [self timeIntervalSinceReferenceDate];
    [output appendBytes:&value length:sizeof(value)];
    cache[self] = @([cache count]);
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    NSTimeInterval value = *(typeof(value) *)(input + *offset);
    *offset += sizeof(value);
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:value];
    [cache addObject:date];
    return date;
}

@end


@implementation NSData (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeData, output);
    uint32_t length = (uint32_t)[self length];
    FastCodingWriteUInt32(length, output);
    [output appendData:self];
    output.length += (4 - ((length % 4) ?: 4));
    cache[self] = @([cache count]);
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    uint32_t length = FastCodingReadUInt32(offset, input);
    NSData *data = [NSData dataWithBytes:(input + *offset) length:length];
    *offset += length + (4 - ((length % 4) ?: 4));
    [cache addObject:self];
    return data;
}

@end


@implementation NSNull (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeNull, output);
}

- (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    return self;
}

@end


@implementation NSDictionary (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeDictionary, output);
    FastCodingWriteUInt32((uint32_t)[self count], output);
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        FastCodingWriteObject(obj, output, cache);
        FastCodingWriteObject(key, output, cache);
    }];
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    uint32_t count = FastCodingReadUInt32(offset, input);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [dict setObject:FastCodingReadObject(offset, input, total, cache) forKey:FastCodingReadObject(offset, input, total, cache)];
    }
    return dict;
}

@end


@implementation NSArray (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeArray, output);
    FastCodingWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FastCodingWriteObject(value, output, cache);
    }
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    uint32_t count = FastCodingReadUInt32(offset, input);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [array addObject:FastCodingReadObject(offset, input, total, cache)];
    }
    return array;
}

@end


@implementation NSSet (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeSet, output);
    FastCodingWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FastCodingWriteObject(value, output, cache);
    }
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    uint32_t count = FastCodingReadUInt32(offset, input);
    NSMutableSet *set = [NSMutableSet setWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FastCodingReadObject(offset, input, total, cache)];
    }
    return set;
}

@end


@implementation NSOrderedSet (FastCoding)

- (void)FC_writeToOutput:(NSMutableData *)output cache:(NSMutableDictionary *)cache
{
    FastCodingWriteUInt32(FCTypeOrderedSet, output);
    FastCodingWriteUInt32((uint32_t)[self count], output);
    for (id value in self)
    {
        FastCodingWriteObject(value, output, cache);
    }
}

+ (instancetype)instanceWithType:(FCType)type offset:(NSUInteger *)offset input:(const void *)input total:(NSUInteger)total cache:(NSMutableArray *)cache
{
    uint32_t count = FastCodingReadUInt32(offset, input);
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:count];
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FastCodingReadObject(offset, input, total, cache)];
    }
    return set;
}

@end
