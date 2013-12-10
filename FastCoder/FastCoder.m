//
//  FastCoding.m
//  FastCoding
//
//  Created by Nick Lockwood on 09/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
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
    FCTypeDate
};


@implementation FastCoder

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

static inline uint32_t FastCodingReadUInt32(NSUInteger *offset, const void *input)
{
    uint32_t value = *(typeof(value) *)(input + *offset);
    *offset += sizeof(value);
    return value;
}

id FastCodingReadObject(NSUInteger *offset, const void *input, NSUInteger total, NSMutableArray *known)
{
    FCType type = (FCType)FastCodingReadUInt32(offset, input);
    switch (type)
    {
        case FCTypeAlias:
        {
            uint32_t index = FastCodingReadUInt32(offset, input);
            return known[index];
        }
        case FCTypeString:
        {
            NSString *string = nil;
            NSUInteger length = strlen(input + *offset) + 1;
            if ((NSUInteger)(*offset + length) > total)
            {
                [NSException raise:NSInvalidArgumentException format:@"Unterminated UTF8 string at location %i", (int32_t)*offset];
            }
            string = [NSString stringWithUTF8String:input + *offset];
            *offset += length + (4 - ((length % 4) ?: 4));
            [known addObject:string];
            return string;
        }
        case FCTypeDictionary:
        {
            uint32_t count = FastCodingReadUInt32(offset, input);
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
            for (uint32_t i = 0; i < count; i++)
            {
                [dict setObject:FastCodingReadObject(offset, input, total, known) forKey:FastCodingReadObject(offset, input, total, known)];
            }
            return dict;
        }
        case FCTypeArray:
        {
            uint32_t count = FastCodingReadUInt32(offset, input);
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
            for (uint32_t i = 0; i < count; i++)
            {
                [array addObject:FastCodingReadObject(offset, input, total, known)];
            }
            return array;
        }
        case FCTypeSet:
        {
            uint32_t count = FastCodingReadUInt32(offset, input);
            NSMutableSet *set = [NSMutableSet setWithCapacity:count];
            for (uint32_t i = 0; i < count; i++)
            {
                [set addObject:FastCodingReadObject(offset, input, total, known)];
            }
            return set;
        }
        case FCTypeOrderedSet:
        {
            uint32_t count = FastCodingReadUInt32(offset, input);
            NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:count];
            for (uint32_t i = 0; i < count; i++)
            {
                [set addObject:FastCodingReadObject(offset, input, total, known)];
            }
            return set;
        }
        case FCTypeTrue:
        {
            return @YES;
        }
        case FCTypeFalse:
        {
            return @NO;
        }
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
            NSNumber *number = @(value);
            [known addObject:number];
            return number;
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
            NSNumber *number = @(value);
            [known addObject:number];
            return number;
        }
        case FCTypeNull:
        {
            return [NSNull null];
        }
        case FCTypeData:
        {
            uint32_t length = FastCodingReadUInt32(offset, input);
            NSData *data = [NSData dataWithBytes:(input + *offset) length:length];
            [known addObject:data];
            *offset += length + (4 - ((length % 4) ?: 4));
            [known addObject:data];
            return data;
        }
        case FCTypeDate:
        {
            NSTimeInterval value = *(typeof(value) *)(input + *offset);
            *offset += sizeof(value);
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:value];
            [known addObject:date];
            return date;
        }
        default:
        {
            char code[5] = {(type & 0xFF000000) >> 24, (type & 0x00FF0000) >> 16, (type & 0x0000FF00) >> 8, type & 0x000000FF, 0};
            [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot decode objects of type: %s", code];
            return nil;
        }
    }
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

static inline void FastCodingWriteUInt32(uint32_t value, NSMutableData *output)
{
    [output appendBytes:&value length:sizeof(value)];
}

void FastCodingWriteObject(id object, NSMutableData *output, NSMutableDictionary *known)
{
    if (object == (void *)kCFBooleanFalse)
    {
        FastCodingWriteUInt32(FCTypeFalse, output);
    }
    else if (object == (void *)kCFBooleanTrue)
    {
        FastCodingWriteUInt32(FCTypeTrue, output);
    }
    else if (object == [NSNull class])
    {
        FastCodingWriteUInt32(FCTypeNull, output);
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        FastCodingWriteUInt32(FCTypeDictionary, output);
        FastCodingWriteUInt32((uint32_t)[object count], output);
        [object enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            FastCodingWriteObject(obj, output, known);
            FastCodingWriteObject(key, output, known);
        }];
    }
    else if ([object isKindOfClass:[NSArray class]])
    {
        FastCodingWriteUInt32(FCTypeArray, output);
        FastCodingWriteUInt32((uint32_t)[object count], output);
        for (id value in object)
        {
            FastCodingWriteObject(value, output, known);
        }
    }
    else if ([object isKindOfClass:[NSSet class]])
    {
        FastCodingWriteUInt32(FCTypeSet, output);
        FastCodingWriteUInt32((uint32_t)[object count], output);
        for (id value in object)
        {
            FastCodingWriteObject(value, output, known);
        }
    }
    else if ([object isKindOfClass:[NSOrderedSet class]])
    {
        FastCodingWriteUInt32(FCTypeOrderedSet, output);
        FastCodingWriteUInt32((uint32_t)[object count], output);
        for (id value in object)
        {
            FastCodingWriteObject(value, output, known);
        }
    }
    else
    {
        //check cache
        NSNumber *alias = known[object];
        if (alias)
        {
            FastCodingWriteUInt32(FCTypeAlias, output);
            FastCodingWriteUInt32((int32_t)[alias intValue], output);
            return;
        }
    
        //cachable object
        known[object] = @([known count]);
        if ([object isKindOfClass:[NSString class]])
        {
            FastCodingWriteUInt32(FCTypeString, output);
            const char *string = [object UTF8String];
            NSUInteger length = strlen(string) + 1;
            [output appendBytes:string length:length];
            output.length += (4 - ((length % 4) ?: 4));
        }
        else if ([object isKindOfClass:[NSNumber class]])
        {
            CFNumberType subtype = CFNumberGetType((CFNumberRef)object);
            switch (subtype)
            {
                case kCFNumberSInt64Type:
                case kCFNumberLongLongType:
                case kCFNumberNSIntegerType:
                {
                    int64_t value = [object longLongValue];
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
                    int32_t value = (int32_t)[object intValue];
                    [output appendBytes:&value length:sizeof(value)];
                    break;
                }
                case kCFNumberFloat32Type:
                case kCFNumberFloatType:
                {
                    FastCodingWriteUInt32(FCTypeFloat32, output);
                    Float32 value = [object floatValue];
                    [output appendBytes:&value length:sizeof(value)];
                    break;
                }
                case kCFNumberFloat64Type:
                case kCFNumberDoubleType:
                case kCFNumberCGFloatType:
                {
                    FastCodingWriteUInt32(FCTypeFloat64, output);
                    Float64 value = [object floatValue];
                    [output appendBytes:&value length:sizeof(value)];
                    break;
                }
            }
        }
        else if ([object isKindOfClass:[NSDate class]])
        {
            FastCodingWriteUInt32(FCTypeDate, output);
            NSTimeInterval value = [object timeIntervalSinceReferenceDate];
            [output appendBytes:&value length:sizeof(value)];
        }
        else if ([object isKindOfClass:[NSData class]])
        {
            FastCodingWriteUInt32(FCTypeData, output);
            uint32_t length = (uint32_t)[object length];
            FastCodingWriteUInt32(length, output);
            [output appendData:object];
            output.length += (4 - (([object length] % 4) ?: 4));
        }
        else
        {
            [NSException raise:NSInvalidArgumentException format:@"FastCoding cannot encode objects of type: %@", [object class]];
        }
    }
}

@end
