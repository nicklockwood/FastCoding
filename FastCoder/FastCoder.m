//
//  FastCoding.m
//
//  Version 2.3
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
#import <objc/message.h>
#import <CoreGraphics/CoreGraphics.h>


#import <Availability.h>
#if __has_feature(objc_arc)
#pragma GCC diagnostic ignored "-Wpedantic"
#warning FastCoding runs slower under ARC. It is recommended that you disable it for this file
#endif


#pragma GCC diagnostic ignored "-Wgnu"
#pragma GCC diagnostic ignored "-Wpointer-arith"
#pragma GCC diagnostic ignored "-Wmissing-prototypes"
#pragma GCC diagnostic ignored "-Wfour-char-constants"
#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"


NSString *const FastCodingException = @"FastCodingException";


static const uint32_t FCIdentifier = 'FAST';
static const uint16_t FCMajorVersion = 2;
static const uint16_t FCMinorVersion = 3;


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
    FCTypeMutableString,
    FCTypeMutableDictionary,
    FCTypeMutableArray,
    FCTypeMutableSet,
    FCTypeMutableOrderedSet,
    FCTypeMutableData,
    FCTypeClassDefinition,
    FCTypeObject,
    FCTypeNil,
    FCTypeURL,
    FCTypePoint,
    FCTypeSize,
    FCTypeRect,
    FCTypeRange,
    FCTypeAffineTransform,
    FCType3DTransform,
    FCTypeMutableIndexSet,
    FCTypeIndexSet,
    FCTypeNSCodedObject
};


#if !__has_feature(objc_arc)
#define FC_AUTORELEASE(x) [(x) autorelease]
#else
#define FC_AUTORELEASE(x) (x)
#endif


#define FC_ASSERT_FITS(length, offset, total) { if ((NSUInteger)((offset) + (length)) > (total)) \
[NSException raise:FastCodingException format:@"Unexpected EOF when parsing object starting at %i", (int32_t)(offset)]; }


#define FC_READ_VALUE(type, offset, input, total) type value; { \
FC_ASSERT_FITS (sizeof(type), offset, total); \
value = *(type *)(input + (offset)); offset += sizeof(value); }


#ifdef TARGET_OS_IPHONE
#define OR_IF_MAC(x)
#else
#define OR_IF_MAC(x) || (x)
#endif


@interface FCNSCoder : NSCoder

@end


@interface FCNSCoder ()
{
    
@public
    __unsafe_unretained id _rootObject;
    __unsafe_unretained NSMutableData *_output;
    __unsafe_unretained id _cache;
    __unsafe_unretained NSMutableDictionary *_classNames;
}

@end


@interface FCNSDecoder : NSCoder

@end


@interface FCNSDecoder ()
{
    
@public
    NSUInteger *_offset;
    const void *_input;
    NSUInteger _total;
    __unsafe_unretained id _cache;
    __unsafe_unretained NSMutableDictionary *_properties;
}

@end


@interface FCClassDefinition : NSObject

@end


@interface FCClassDefinition ()
{

@public
    __unsafe_unretained NSString *_className;
    __unsafe_unretained NSArray *_propertyKeys;
}

@end


@interface NSObject (FastCoding_Private)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder;

@end


static inline NSUInteger FCCacheReadObject(__unsafe_unretained id object, __unsafe_unretained id cache)
{
    
#ifdef DEBUG
    
    NSUInteger offset = [(NSArray *)cache count];
    [cache addObject:object];
    return offset;
    
#else
    
    if (cache)
    {
        NSUInteger offset = (NSUInteger)CFDataGetLength((__bridge CFMutableDataRef)cache);
        CFDataAppendBytes((__bridge CFMutableDataRef)cache, (void *)&object, sizeof(id));
        return offset;
    }
    return NSNotFound;
    
#endif
    
}

static inline void FCReplaceCachedObject(NSUInteger index, __unsafe_unretained id object, __unsafe_unretained id cache)
{
    
#ifdef DEBUG
    
    [cache replaceObjectAtIndex:index withObject:object];
    
#else
    
    if (cache) CFDataReplaceBytes((__bridge CFMutableDataRef)cache, CFRangeMake((CFIndex)index, sizeof(id)), (void *)&object, sizeof(id));
    
#endif
    
}

static inline id FCCachedObjectAtIndex(NSUInteger index, __unsafe_unretained id cache)
{
    
#ifdef DEBUG
    
    return cache[index];
    
#else
    
    return cache? ((__unsafe_unretained id *)(void *)CFDataGetBytePtr((__bridge CFMutableDataRef)cache))[index]: nil;
    
#endif
    
}

static inline uint32_t FCReadRawUInt32(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(uint32_t, *decoder->_offset, decoder->_input, decoder->_total);
    return value;
}

static inline double FCReadRawDouble(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(double_t, *decoder->_offset, decoder->_input, decoder->_total);
    return value;
}

static id FCReadRawString(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing NSString *string = nil;
    NSUInteger length = strlen(decoder->_input + *decoder->_offset) + 1;
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *decoder->_offset, decoder->_total);
    if (length > 1)
    {
        string = CFBridgingRelease(CFStringCreateWithBytes(NULL, decoder->_input + *decoder->_offset,
                                                           (CFIndex)length - 1, kCFStringEncodingUTF8, false));
    }
    else
    {
        string = @"";
    }
    *decoder->_offset += paddedLength;
    return string;
}


static id FCReadObject(__unsafe_unretained FCNSDecoder *decoder);

static id FCReadNull(__unused __unsafe_unretained FCNSDecoder *decoder)
{
    return [NSNull null];
}

static id FCReadAlias(__unsafe_unretained FCNSDecoder *decoder)
{
    return FCCachedObjectAtIndex(FCReadRawUInt32(decoder), decoder->_cache);
}

static id FCReadString(__unsafe_unretained FCNSDecoder *decoder)
{
    NSString *string = FCReadRawString(decoder);
    FCCacheReadObject(string, decoder->_cache);
    return string;
}

static id FCReadMutableString(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing NSMutableString *string = nil;
    NSUInteger length = strlen(decoder->_input + *decoder->_offset) + 1;
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *decoder->_offset, decoder->_total);
    if (length > 1)
    {
        string = FC_AUTORELEASE([[NSMutableString alloc] initWithBytes:decoder->_input + *decoder->_offset length:length - 1 encoding:NSUTF8StringEncoding]);
    }
    else
    {
        string = [NSMutableString string];
    }
    *decoder->_offset += paddedLength;
    FCCacheReadObject(string, decoder->_cache);
    return string;
}

static id FCReadDictionary(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSDictionary *dict = nil;
    if (count)
    {        
        __autoreleasing id *keys = (__autoreleasing id *)malloc(count * sizeof(id));
        __autoreleasing id *objects = (__autoreleasing id *)malloc(count * sizeof(id));
        for (uint32_t i = 0; i < count; i++)
        {
            objects[i] = FCReadObject(decoder);
            keys[i] = FCReadObject(decoder);
        }
        
        dict = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:count];
        free(objects);
        free(keys);
    }
    else
    {
        dict = @{};
    }
    FCCacheReadObject(dict, decoder->_cache);
    return dict;
}

static id FCReadMutableDictionary(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSMutableDictionary *dict = CFBridgingRelease(CFDictionaryCreateMutable(NULL, (CFIndex)count, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    FCCacheReadObject(dict, decoder->_cache);
    for (uint32_t i = 0; i < count; i++)
    {
        __autoreleasing id value = FCReadObject(decoder);
        __autoreleasing id key = FCReadObject(decoder);
        CFDictionarySetValue((__bridge CFMutableDictionaryRef)dict, (__bridge const void *)key, (__bridge const void *)value);
    }
    return dict;
}

static id FCReadArray(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSArray *array = nil;
    if (count)
    {
        __autoreleasing id *objects = (__autoreleasing id *)malloc(count * sizeof(id));
        for (uint32_t i = 0; i < count; i++)
        {
            objects[i] = FCReadObject(decoder);
        }
        array = [NSArray arrayWithObjects:objects count:count];
        free(objects);
    }
    else
    {
        array = @[];
    }
    FCCacheReadObject(array, decoder->_cache);
    return array;
}

static id FCReadMutableArray(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    FCCacheReadObject(array, decoder->_cache);
    for (uint32_t i = 0; i < count; i++)
    {
        CFArrayAppendValue((__bridge CFMutableArrayRef)array, (__bridge void *)FCReadObject(decoder));
    }
    return array;
}

static id FCReadSet(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSSet *set = nil;
    if (count)
    {
        __autoreleasing id *objects = (__autoreleasing id *)malloc(count * sizeof(id));
        for (uint32_t i = 0; i < count; i++)
        {
            objects[i] = FCReadObject(decoder);
        }
        set = [NSSet setWithObjects:objects count:count];
        free(objects);
    }
    else
    {
        set = [NSSet set];
    }
    FCCacheReadObject(set, decoder->_cache);
    return set;
}

static id FCReadMutableSet(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSMutableSet *set = [NSMutableSet setWithCapacity:count];
    FCCacheReadObject(set, decoder->_cache);
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FCReadObject(decoder)];
    }
    return set;
}

static id FCReadOrderedSet(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSOrderedSet *set = nil;
    if (count)
    {
        __autoreleasing id *objects = (__autoreleasing id *)malloc(count * sizeof(id));
        for (uint32_t i = 0; i < count; i++)
        {
            objects[i] = FCReadObject(decoder);
        }
        set = [NSOrderedSet orderedSetWithObjects:objects count:count];
        free(objects);
    }
    else
    {
        set = [NSOrderedSet orderedSet];
    }
    FCCacheReadObject(set, decoder->_cache);
    return set;
}

static id FCReadMutableOrderedSet(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t count = FCReadRawUInt32(decoder);
    __autoreleasing NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:count];
    FCCacheReadObject(set, decoder->_cache);
    for (uint32_t i = 0; i < count; i++)
    {
        [set addObject:FCReadObject(decoder)];
    }
    return set;
}

static id FCReadTrue(__unused __unsafe_unretained FCNSDecoder *decoder)
{
    return @YES;
}

static id FCReadFalse(__unused __unsafe_unretained FCNSDecoder *decoder)
{
    return @NO;
}

static id FCReadInt32(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(int32_t, *decoder->_offset, decoder->_input, decoder->_total);
    __autoreleasing NSNumber *number = @(value);
    FCCacheReadObject(number, decoder->_cache);
    return number;
}

static id FCReadInt64(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(int64_t, *decoder->_offset, decoder->_input, decoder->_total);
    __autoreleasing NSNumber *number = @(value);
    FCCacheReadObject(number, decoder->_cache);
    return number;
}

static id FCReadFloat32(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(Float32, *decoder->_offset, decoder->_input, decoder->_total);
    __autoreleasing NSNumber *number = @(value);
    FCCacheReadObject(number, decoder->_cache);
    return number;
}

static id FCReadFloat64(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(Float64, *decoder->_offset, decoder->_input, decoder->_total);
    __autoreleasing NSNumber *number = @(value);
    FCCacheReadObject(number, decoder->_cache);
    return number;
}

static id FCReadData(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t length = FCReadRawUInt32(decoder);
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *decoder->_offset, decoder->_total);
    __autoreleasing NSData *data = [NSData dataWithBytes:(decoder->_input + *decoder->_offset) length:length];
    *decoder->_offset += paddedLength;
    FCCacheReadObject(data, decoder->_cache);
    return data;
}

static id FCReadMutableData(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t length = FCReadRawUInt32(decoder);
    NSUInteger paddedLength = length + (4 - ((length % 4) ?: 4));
    FC_ASSERT_FITS(paddedLength, *decoder->_offset, decoder->_total);
    __autoreleasing NSMutableData *data = [NSMutableData dataWithBytes:(decoder->_input + *decoder->_offset) length:length];
    *decoder->_offset += paddedLength;
    FCCacheReadObject(data, decoder->_cache);
    return data;
}

static id FCReadDate(__unsafe_unretained FCNSDecoder *decoder)
{
    FC_READ_VALUE(NSTimeInterval, *decoder->_offset, decoder->_input, decoder->_total);
    __autoreleasing NSDate *date = [NSDate dateWithTimeIntervalSince1970:value];
    FCCacheReadObject(date, decoder->_cache);
    return date;
}

static id FCReadClassDefinition(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing FCClassDefinition *definition = FC_AUTORELEASE([[FCClassDefinition alloc] init]);
    FCCacheReadObject(definition, decoder->_cache);
    definition->_className = FCReadRawString(decoder);
    uint32_t count = FCReadRawUInt32(decoder);
    if (count)
    {
        __autoreleasing id *objects = (__autoreleasing id *)malloc(count * sizeof(id));
        for (uint32_t i = 0; i < count; i++)
        {
            objects[i] = FCReadRawString(decoder);
        }
        __autoreleasing NSArray *propertyKeys = [NSArray arrayWithObjects:objects count:count];
        definition->_propertyKeys = propertyKeys;
        free(objects);
    }
    
    //now return the actual object instance
    return FCReadObject(decoder);
}

static id FCReadObjectInstance(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing FCClassDefinition *definition = FCCachedObjectAtIndex(FCReadRawUInt32(decoder), decoder->_cache);
    __autoreleasing Class objectClass = NSClassFromString(definition->_className);
    __autoreleasing id object = nil;
    if (objectClass)
    {
        object = FC_AUTORELEASE([[objectClass alloc] init]);
    }
    else if (definition->_className)
    {
        object = [NSMutableDictionary dictionaryWithObject:definition->_className forKey:@"$class"];
    }
    else if (object)
    {
        object = [NSMutableDictionary dictionary];
    }
    NSUInteger cacheIndex = FCCacheReadObject(object, decoder->_cache);
    for (__unsafe_unretained NSString *key in definition->_propertyKeys)
    {
        [object setValue:FCReadObject(decoder) forKey:key];
    }
    id newObject = [object awakeAfterFastCoding];
    if (newObject != object)
    {
        //TODO: this is only a partial solution, as any objects that referenced
        //this object between when it was created and now will have received incorrect instance
        FCReplaceCachedObject(cacheIndex, newObject, decoder->_cache);
    }
    return newObject;
}

static id FCReadNil(__unused __unsafe_unretained FCNSDecoder *decoder)
{
    return nil;
}

static id FCReadURL(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing NSURL *URL = [NSURL URLWithString:FCReadObject(decoder) relativeToURL:FCReadObject(decoder)];
    FCCacheReadObject(URL, decoder->_cache);
    return URL;
}

static id FCReadPoint(__unsafe_unretained FCNSDecoder *decoder)
{
    CGPoint point = {(CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)};
    NSValue *value = [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCReadSize(__unsafe_unretained FCNSDecoder *decoder)
{
    CGSize size = {(CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)};
    NSValue *value = [NSValue valueWithBytes:&size objCType:@encode(CGSize)];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCReadRect(__unsafe_unretained FCNSDecoder *decoder)
{
    CGRect rect =
    {
        {(CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)},
        {(CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)}
    };
    NSValue *value = [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCReadRange(__unsafe_unretained FCNSDecoder *decoder)
{
    NSRange range = {FCReadRawUInt32(decoder), FCReadRawUInt32(decoder)};
    NSValue *value = [NSValue valueWithBytes:&range objCType:@encode(NSRange)];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCReadAffineTransform(__unsafe_unretained FCNSDecoder *decoder)
{
    CGAffineTransform transform =
    {
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)
    };
    NSValue *value = [NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCRead3DTransform(__unsafe_unretained FCNSDecoder *decoder)
{
    CGFloat transform[] =
    {
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder),
        (CGFloat)FCReadRawDouble(decoder), (CGFloat)FCReadRawDouble(decoder)
    };
    NSValue *value = [NSValue valueWithBytes:&transform objCType:@encode(CGFloat[16])];
    FCCacheReadObject(value, decoder->_cache);
    return value;
}

static id FCReadMutableIndexSet(__unsafe_unretained FCNSDecoder *decoder)
{
    uint32_t rangeCount = FCReadRawUInt32(decoder);
    __autoreleasing NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    FCCacheReadObject(indexSet, decoder->_cache);
    for (uint32_t i = 0; i < rangeCount; i++)
    {
        NSRange range = {FCReadRawUInt32(decoder), FCReadRawUInt32(decoder)};
        [indexSet addIndexesInRange:range];
    }
    return indexSet;
}

static id FCReadIndexSet(__unsafe_unretained FCNSDecoder *decoder)
{
    __autoreleasing NSIndexSet *indexSet;
    uint32_t rangeCount = FCReadRawUInt32(decoder);
    if (rangeCount == 1)
    {
        //common case optimisation
        NSRange range = {FCReadRawUInt32(decoder), FCReadRawUInt32(decoder)};
        indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
    }
    else
    {
        indexSet = [NSMutableIndexSet indexSet];
        for (uint32_t i = 0; i < rangeCount; i++)
        {
            NSRange range = {FCReadRawUInt32(decoder), FCReadRawUInt32(decoder)};
            [(NSMutableIndexSet *)indexSet addIndexesInRange:range];
        }
        indexSet = [indexSet copy];
        
    }
    FCCacheReadObject(indexSet, decoder->_cache);
    return indexSet;
}

static id FCReadNSCodedObject(__unsafe_unretained FCNSDecoder *decoder)
{
    NSString *className = FCReadObject(decoder);
    NSMutableDictionary *oldProperties = decoder->_properties;
    decoder->_properties = [NSMutableDictionary dictionary];
    while (true)
    {
        id object = FCReadObject(decoder);
        if (!object) break;
        NSString *key = FCReadObject(decoder);
        decoder->_properties[key] = object;
    }
    id object = [[NSClassFromString(className) alloc] initWithCoder:decoder];
    decoder->_properties = oldProperties;
    FCCacheReadObject(object, decoder->_cache);
    return object;
}

static id FCReadObject(__unsafe_unretained FCNSDecoder *decoder)
{
    static id (*constructors[])(FCNSDecoder *) =
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
        FCReadMutableString,
        FCReadMutableDictionary,
        FCReadMutableArray,
        FCReadMutableSet,
        FCReadMutableOrderedSet,
        FCReadMutableData,
        FCReadClassDefinition,
        FCReadObjectInstance,
        FCReadNil,
        FCReadURL,
        FCReadPoint,
        FCReadSize,
        FCReadRect,
        FCReadRange,
        FCReadAffineTransform,
        FCRead3DTransform,
        FCReadMutableIndexSet,
        FCReadIndexSet,
        FCReadNSCodedObject
    };
    
    FCType type = FCReadRawUInt32(decoder);
    if ((uint32_t)type > sizeof(constructors) / sizeof(id))
    {
        [NSException raise:FastCodingException format:@"FastCoding cannot decode object of type: %i", type];
        return nil;
    }
    return ((id (*)(FCNSDecoder *))constructors[type])(decoder);
}

static inline NSUInteger FCCacheWrittenObject(__unsafe_unretained id object, __unsafe_unretained id cache)
{
    NSUInteger count = (NSUInteger)CFDictionaryGetCount((CFMutableDictionaryRef)cache);
    CFDictionarySetValue((CFMutableDictionaryRef)cache, (__bridge const void *)(object), (const void *)(count + 1));
    return count;
}

static inline NSUInteger FCIndexOfCachedObject(__unsafe_unretained id object, __unsafe_unretained id cache)
{
    const void *index = CFDictionaryGetValue((__bridge CFMutableDictionaryRef)cache, (__bridge const void *)object);
    if (index)
    {
        return ((NSUInteger)index) - 1;
    }
    return NSNotFound;
}

static inline void FCWriteUInt32(uint32_t value, __unsafe_unretained NSMutableData *output)
{
    [output appendBytes:&value length:sizeof(value)];
}

static inline void FCWriteDouble(double_t value, __unsafe_unretained NSMutableData *output)
{
    [output appendBytes:&value length:sizeof(value)];
}

static inline void FCWriteString(__unsafe_unretained NSString *string, __unsafe_unretained NSMutableData *output)
{
    const char *utf8 = [string UTF8String];
    NSUInteger length = strlen(utf8) + 1;
    [output appendBytes:utf8 length:length];
    output.length += (4 - ((length % 4) ?: 4));
}

static void FCWriteObject(__unsafe_unretained id object, __unsafe_unretained FCNSCoder *coder)
{
    if (object)
    {
        //check cache
        NSUInteger index = FCIndexOfCachedObject(object, coder->_cache);
        if (index != NSNotFound)
        {
            FCWriteUInt32(FCTypeAlias, coder->_output);
            FCWriteUInt32((uint32_t)index, coder->_output);
        }
        else
        {
            [object FC_encodeWithCoder:coder];
        }
    }
    else
    {
        FCWriteUInt32(FCTypeNil, coder->_output);
    }
}

const void *FCRetainCallback(__unused CFAllocatorRef allocator, const void* value)
{
    return value;
}

void FCReleaseCallback(__unused CFAllocatorRef allocator, __unused const void* value)
{
    //does nothing
}

CFStringRef FCCopyDescriptionCallback(__unused const void* value)
{
    return nil;
}

Boolean FCDictionaryEqualCallback(const void* value1, const void* value2)
{
    return value1 == value2;
}

CFHashCode FCDictionaryHashCallback(const void* value)
{
    return (CFHashCode)value;
}


@implementation FastCoder

+ (id)objectWithData:(NSData *)data
{
    NSUInteger length = [data length];
    if (length < sizeof(FCHeader))
    {
        //not a valid FastArchive
        return nil;
    }
    
    //read header
    FCHeader header;
    const void *input = data.bytes;
    memcpy(&header, input, sizeof(header));
    if (header.identifier != FCIdentifier)
    {
        //not a FastArchive
        return nil;
    }
    if (header.majorVersion != FCMajorVersion)
    {
        //not compatible
        NSLog(@"This version of the FastCoding library doesn't support FastCoding version %i.%i files", header.majorVersion, header.minorVersion);
        return nil;
    }
    
    //create decoder
    NSUInteger offset = sizeof(header);
    FCNSDecoder *decoder = FC_AUTORELEASE([[FCNSDecoder alloc] init]);
    decoder->_input = input;
    decoder->_offset = &offset;
    decoder->_total = length;
    
    //read data
    uint32_t objectCount = FCReadRawUInt32(decoder);
    ;
    
#ifdef DEBUG
    
    __autoreleasing NSMutableArray *cache = [NSMutableArray arrayWithCapacity:objectCount * sizeof(id)];

#else
    
    __autoreleasing NSMutableData *cache = [NSMutableData dataWithCapacity:objectCount * sizeof(id)];
    
#endif
    
    decoder->_cache = cache;
    return FCReadObject(decoder);
}

+ (NSData *)dataWithRootObject:(id)object
{
    if (object)
    {
        //write header
        FCHeader header = {FCIdentifier, FCMajorVersion, FCMinorVersion};
        NSMutableData *output = [NSMutableData dataWithLength:sizeof(header)];
        memcpy(output.mutableBytes, &header, sizeof(header));
        
        //object count placeholder
        FCWriteUInt32(0, output);
        
        //set up cache
        const CFDictionaryKeyCallBacks keyCallbacks =
        {
            0,
            FCRetainCallback,
            FCReleaseCallback,
            FCCopyDescriptionCallback,
            FCDictionaryEqualCallback,
            FCDictionaryHashCallback
        };
        
        const CFDictionaryValueCallBacks valueCallbacks =
        {
            0,
            FCRetainCallback,
            FCReleaseCallback,
            FCCopyDescriptionCallback,
            FCDictionaryEqualCallback
        };
        
        @autoreleasepool
        {
            //create coder
            NSMutableDictionary *cache = CFBridgingRelease(CFDictionaryCreateMutable(NULL, 0, &keyCallbacks, &valueCallbacks));
            FCNSCoder *coder = FC_AUTORELEASE([[FCNSCoder alloc] init]);
            coder->_rootObject = object;
            coder->_output = output;
            coder->_cache = cache;
            coder->_classNames = [NSMutableDictionary dictionary];
            
            //write object
            FCWriteObject(object, coder);
            
            //set object count and return
            uint32_t objectCount = (uint32_t)[cache count];
            [output replaceBytesInRange:NSMakeRange(sizeof(header), sizeof(uint32_t)) withBytes:&objectCount];
            return output;
        }
    }
    return nil;
}

@end


@implementation FCNSCoder

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (void)encodeObject:(__unsafe_unretained id)objv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(objv, self);
    FCWriteObject(key, self);
}

- (void)encodeConditionalObject:(id)objv forKey:(__unsafe_unretained NSString *)key
{
    if (FCIndexOfCachedObject(objv, _cache) != NSNotFound)
    {
        FCWriteObject(objv, self);
        FCWriteObject(key, self);
    }
}

- (void)encodeBool:(BOOL)boolv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(boolv), self);
    FCWriteObject(key, self);
}

- (void)encodeInt:(int)intv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(intv), self);
    FCWriteObject(key, self);
}

- (void)encodeInt32:(int32_t)intv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(intv), self);
    FCWriteObject(key, self);
}

- (void)encodeInt64:(int64_t)intv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(intv), self);
    FCWriteObject(key, self);
}

- (void)encodeFloat:(float)realv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(realv), self);
    FCWriteObject(key, self);
}

- (void)encodeDouble:(double)realv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject(@(realv), self);
    FCWriteObject(key, self);
}

- (void)encodeBytes:(const uint8_t *)bytesp length:(NSUInteger)lenv forKey:(__unsafe_unretained NSString *)key
{
    FCWriteObject([NSData dataWithBytes:bytesp length:lenv], self);
    FCWriteObject(key, self);
}

@end


@implementation FCNSDecoder

- (id)decodeObjectForKey:(__unsafe_unretained NSString *)key
{
    return _properties[key];
}

- (BOOL)decodeBoolForKey:(__unsafe_unretained NSString *)key
{
    return [_properties[key] boolValue];
}

- (int)decodeIntForKey:(__unsafe_unretained NSString *)key
{
    return [_properties[key] intValue];
}

- (int32_t)decodeInt32ForKey:(__unsafe_unretained NSString *)key
{
    return (int32_t)[_properties[key] longValue];
}

- (int64_t)decodeInt64ForKey:(__unsafe_unretained NSString *)key
{
    return [_properties[key] longLongValue];
}

- (float)decodeFloatForKey:(__unsafe_unretained NSString *)key
{
    return [_properties[key] floatValue];
}

- (double)decodeDoubleForKey:(__unsafe_unretained NSString *)key
{
    return [_properties[key] doubleValue];
}

- (const uint8_t *)decodeBytesForKey:(__unsafe_unretained NSString *)key returnedLength:(NSUInteger *)lengthp
{
    __autoreleasing NSData *data = _properties[key];
    *lengthp = [data length];
    return data.bytes;
}

@end


@implementation FCClassDefinition : NSObject

@end


@implementation NSObject (FastCoding)

+ (NSArray *)fastCodingKeys
{
    __autoreleasing NSMutableArray *codableKeys = [NSMutableArray array];
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(self, &propertyCount);
    for (unsigned int i = 0; i < propertyCount; i++)
    {
        //get property
        objc_property_t property = properties[i];
        const char *propertyName = property_getName(property);
        NSString *key = @(propertyName);
        
        //see if there is a backing ivar
        char *ivar = property_copyAttributeValue(property, "V");
        if (ivar)
        {
            //check if ivar has KVC-compliant name
            NSString *ivarName = @(ivar);
            if ([ivarName isEqualToString:key] || [ivarName isEqualToString:[@"_" stringByAppendingString:key]])
            {
                //setValue:forKey: will work
                [codableKeys addObject:key];
            }
            free(ivar);
        }
    }
    free(properties);
    return codableKeys;
}

+ (NSArray *)FC_aggregatePropertyKeys
{
    __autoreleasing NSArray *codableKeys = nil;
    codableKeys = objc_getAssociatedObject(self, _cmd);
    if (codableKeys == nil)
    {
        codableKeys = [NSMutableArray array];
        Class subclass = [self class];
        while (subclass != [NSObject class])
        {
            [(NSMutableArray *)codableKeys addObjectsFromArray:[subclass fastCodingKeys]];
            subclass = [subclass superclass];
        }
        codableKeys = [NSArray arrayWithArray:codableKeys];
        
        //make the association atomically so that we don't need to bother with an @synchronize
        objc_setAssociatedObject(self, _cmd, codableKeys, OBJC_ASSOCIATION_RETAIN);
    }
    return codableKeys;
}

- (id)awakeAfterFastCoding
{
    return self;
}

- (Class)classForFastCoding
{
    return [self classForCoder];
}

- (BOOL)preferFastCoding
{
    return NO;
}

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    //handle NSCoding
    if (![self preferFastCoding] && [self conformsToProtocol:@protocol(NSCoding)])
    {
        //write object
        FCWriteUInt32(FCTypeNSCodedObject, coder->_output);
        FCWriteObject(NSStringFromClass([self classForCoder]), coder);
        [(id <NSCoding>)self encodeWithCoder:coder];
        FCWriteUInt32(FCTypeNil, coder->_output);
        FCCacheWrittenObject(self, coder->_cache);
        return;
    }
    
    //write class definition
    Class objectClass = [self classForFastCoding];
    NSUInteger classIndex = FCIndexOfCachedObject(objectClass, coder->_cache);
    __autoreleasing NSArray *propertyKeys = [objectClass FC_aggregatePropertyKeys];
    if (classIndex == NSNotFound)
    {
        classIndex = FCCacheWrittenObject(objectClass, coder->_cache);
        FCWriteUInt32(FCTypeClassDefinition, coder->_output);
        FCWriteString(NSStringFromClass(objectClass), coder->_output);
        FCWriteUInt32((uint32_t)[propertyKeys count], coder->_output);
        for (__unsafe_unretained id value in propertyKeys)
        {
            FCWriteString(value, coder->_output);
        }
    }

    //write object
    FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(FCTypeObject, coder->_output);
    FCWriteUInt32((uint32_t)classIndex, coder->_output);
    for (__unsafe_unretained NSString *key in propertyKeys)
    {
        FCWriteObject([self valueForKey:key], coder);
    }
}

@end


@implementation NSString (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(([self classForCoder] == [NSMutableString class])? FCTypeMutableString: FCTypeString, coder->_output);
    FCWriteString(self, coder->_output);
}

@end


@implementation NSNumber (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    if (self == (void *)kCFBooleanFalse)
    {
        FCWriteUInt32(FCTypeFalse, coder->_output);
    }
    else if (self == (void *)kCFBooleanTrue)
    {
        FCWriteUInt32(FCTypeTrue, coder->_output);
    }
    else
    {
        FCCacheWrittenObject(self, coder->_cache);
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
                    FCWriteUInt32(FCTypeInt64, coder->_output);
                    [coder->_output appendBytes:&value length:sizeof(value)];
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
                FCWriteUInt32(FCTypeInt32, coder->_output);
                int32_t value = (int32_t)[self intValue];
                [coder->_output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat32Type:
            case kCFNumberFloatType:
            {
                FCWriteUInt32(FCTypeFloat32, coder->_output);
                Float32 value = [self floatValue];
                [coder->_output appendBytes:&value length:sizeof(value)];
                break;
            }
            case kCFNumberFloat64Type:
            case kCFNumberDoubleType:
            case kCFNumberCGFloatType:
            {
                FCWriteUInt32(FCTypeFloat64, coder->_output);
                Float64 value = [self floatValue];
                [coder->_output appendBytes:&value length:sizeof(value)];
                break;
            }
        }
    }
}

@end


@implementation NSDate (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(FCTypeDate, coder->_output);
    NSTimeInterval value = [self timeIntervalSince1970];
    [coder->_output appendBytes:&value length:sizeof(value)];
}

@end


@implementation NSData (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(([self classForCoder] == [NSMutableData class])? FCTypeMutableData: FCTypeData, coder->_output);
    uint32_t length = (uint32_t)[self length];
    FCWriteUInt32(length, coder->_output);
    [coder->_output appendData:self];
    coder->_output.length += (4 - ((length % 4) ?: 4));
}

@end


@implementation NSNull (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCWriteUInt32(FCTypeNull, coder->_output);
}

@end


@implementation NSDictionary (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    //alias keypath
    __autoreleasing NSString *aliasKeypath = self[@"$alias"];
    if ([self count] == 1 && aliasKeypath)
    {
        __autoreleasing id node = coder->_rootObject;
        NSArray *parts = [aliasKeypath componentsSeparatedByString:@"."];
        for (__unsafe_unretained NSString *key in parts)
        {
            if ([node isKindOfClass:[NSArray class]])
            {
                node = ((NSArray *)node)[(NSUInteger)[key integerValue]];
            }
            else
            {
                node = [node valueForKey:key];
            }
        }
        FCWriteObject(node, coder);
        return;
    }
    
    //object bootstrapping
    __autoreleasing NSString *className = self[@"$class"];
    if (className)
    {
        //get class definition
        __autoreleasing NSArray *propertyKeys = [[self allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != '$class'"]];
        __autoreleasing FCClassDefinition *objectClass = coder->_classNames[className];
        if (objectClass)
        {
            //check that existing class definition contains all keys
            __autoreleasing NSMutableArray *keys = nil;
            for (__unsafe_unretained id key in propertyKeys)
            {
                if (![objectClass->_propertyKeys containsObject:key])
                {
                    keys = keys ?: [NSMutableArray array];
                    [keys addObject:key];
                }
            }
            propertyKeys = objectClass->_propertyKeys;
            if (keys)
            {
                //we need to create a new class definition that includes extra keys
                propertyKeys = [propertyKeys arrayByAddingObjectsFromArray:keys];
                objectClass = nil;
            }
        }
        if (!objectClass)
        {
            //create class definition
            objectClass = FC_AUTORELEASE([[FCClassDefinition alloc] init]);
            objectClass->_className = className;
            objectClass->_propertyKeys = propertyKeys;
            coder->_classNames[className] = objectClass;
        }
        
        //write class definition
        NSUInteger classIndex = FCIndexOfCachedObject(objectClass, coder->_cache);
        if (classIndex == NSNotFound)
        {
            classIndex = FCCacheWrittenObject(objectClass, coder->_cache);
            FCWriteUInt32(FCTypeClassDefinition, coder->_output);
            FCWriteString(objectClass->_className, coder->_output);
            FCWriteUInt32((uint32_t)[propertyKeys count], coder->_output);
            for (__unsafe_unretained id key in propertyKeys)
            {
                //convert each to a string using -description, just in case
                FCWriteString([key description], coder->_output);
            }
        }
        
        //write object
        FCCacheWrittenObject(self, coder->_cache);
        FCWriteUInt32(FCTypeObject, coder->_output);
        FCWriteUInt32((uint32_t)classIndex, coder->_output);
        for (__unsafe_unretained NSString *key in propertyKeys)
        {
            FCWriteObject(self[key], coder);
        }
        return;
    }
    
    //ordinary dictionary
    BOOL mutable = ([self classForCoder] == [NSMutableDictionary class]);
    if (mutable) FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(mutable? FCTypeMutableDictionary: FCTypeDictionary, coder->_output);
    FCWriteUInt32((uint32_t)[self count], coder->_output);
    [self enumerateKeysAndObjectsUsingBlock:^(__unsafe_unretained id key, __unsafe_unretained id obj, __unused BOOL *stop) {
        FCWriteObject(obj, coder);
        FCWriteObject(key, coder);
    }];
    if (!mutable) FCCacheWrittenObject(self, coder->_cache);
}

@end


@implementation NSArray (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    BOOL mutable = ([self classForCoder] == [NSMutableArray class]);
    if (mutable) FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(mutable? FCTypeMutableArray: FCTypeArray, coder->_output);
    FCWriteUInt32((uint32_t)[self count], coder->_output);
    for (__unsafe_unretained id value in self)
    {
        FCWriteObject(value, coder);
    }
    if (!mutable) FCCacheWrittenObject(self, coder->_cache);
}

@end



@implementation NSSet (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    BOOL mutable = ([self classForCoder] == [NSMutableSet class]);
    if (mutable) FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(mutable? FCTypeMutableSet: FCTypeSet, coder->_output);
    FCWriteUInt32((uint32_t)[self count], coder->_output);
    for (__unsafe_unretained id value in self)
    {
        FCWriteObject(value, coder);
    }
    if (!mutable) FCCacheWrittenObject(self, coder->_cache);
}

@end


@implementation NSOrderedSet (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    BOOL mutable = ([self classForCoder] == [NSMutableOrderedSet class]);
    if (mutable) FCCacheWrittenObject(self, coder->_cache);
    FCWriteUInt32(mutable? FCTypeMutableOrderedSet: FCTypeOrderedSet, coder->_output);
    FCWriteUInt32((uint32_t)[self count], coder->_output);
    for (__unsafe_unretained id value in self)
    {
        FCWriteObject(value, coder);
    }
    if (!mutable) FCCacheWrittenObject(self, coder->_cache);
}

@end


@implementation NSIndexSet (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    BOOL mutable = ([self classForCoder] == [NSMutableIndexSet class]);
    if (mutable) FCCacheWrittenObject(self, coder->_cache);
    
    uint32_t __block rangeCount = 0; // wish we could get this directly from NSIndexSet...
    [self enumerateRangesUsingBlock:^(__unused NSRange range, __unused BOOL *stop) {
        rangeCount ++;
    }];

    FCWriteUInt32(mutable? FCTypeMutableIndexSet: FCTypeIndexSet, coder->_output);
    FCWriteUInt32(rangeCount, coder->_output);
    [self enumerateRangesUsingBlock:^(NSRange range, __unused BOOL *stop) {
        FCWriteUInt32((uint32_t)range.location, coder->_output);
        FCWriteUInt32((uint32_t)range.length, coder->_output);
    }];
    
    if (!mutable) FCCacheWrittenObject(self, coder->_cache);
}

@end


@implementation NSURL (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCWriteUInt32(FCTypeURL, coder->_output);
    FCWriteObject(self.relativeString, coder);
    FCWriteObject(self.baseURL, coder);
    FCCacheWrittenObject(self, coder->_cache);
}

@end


@implementation NSValue (FastCoding)

- (void)FC_encodeWithCoder:(__unsafe_unretained FCNSCoder *)coder
{
    FCCacheWrittenObject(self, coder->_cache);
    const char *type = [self objCType];
    if (strcmp(type, @encode(CGPoint)) == 0 OR_IF_MAC(strcmp(type, @encode(NSPoint)) == 0))
    {
        CGFloat point[2];
        [self getValue:&point];
        FCWriteUInt32(FCTypePoint, coder->_output);
        FCWriteDouble((double_t)point[0], coder->_output);
        FCWriteDouble((double_t)point[1], coder->_output);
    }
    else if (strcmp(type, @encode(CGSize)) == 0 OR_IF_MAC(strcmp(type, @encode(NSSize)) == 0))
    {
        CGFloat size[2];
        [self getValue:&size];
        FCWriteUInt32(FCTypeSize, coder->_output);
        FCWriteDouble((double_t)size[0], coder->_output);
        FCWriteDouble((double_t)size[1], coder->_output);
    }
    else if (strcmp(type, @encode(CGRect)) == 0 OR_IF_MAC(strcmp(type, @encode(NSRect)) == 0))
    {
        CGFloat rect[4];
        [self getValue:&rect];
        FCWriteUInt32(FCTypeRect, coder->_output);
        FCWriteDouble((double_t)rect[0], coder->_output);
        FCWriteDouble((double_t)rect[1], coder->_output);
        FCWriteDouble((double_t)rect[2], coder->_output);
        FCWriteDouble((double_t)rect[3], coder->_output);
    }
    else if (strcmp(type, @encode(NSRange)) == 0)
    {
        NSUInteger range[2];
        [self getValue:&range];
        FCWriteUInt32(FCTypeRange, coder->_output);
        FCWriteUInt32((uint32_t)range[0], coder->_output);
        FCWriteUInt32((uint32_t)range[1], coder->_output);
    }
    else if (strcmp(type, @encode(CGAffineTransform)) == 0)
    {
        CGFloat transform[6];
        [self getValue:&transform];
        FCWriteUInt32(FCTypeAffineTransform, coder->_output);
        for (NSUInteger i = 0; i < 6; i++)
        {
            FCWriteDouble((double_t)transform[i], coder->_output);
        }
    }
    else if ([@(type) hasPrefix:@"{CATransform3D"])
    {
        CGFloat transform[16];
        [self getValue:&transform];
        FCWriteUInt32(FCType3DTransform, coder->_output);
        for (NSUInteger i = 0; i < 16; i++)
        {
            FCWriteDouble((double_t)transform[i], coder->_output);
        }
    }
    else
    {
        [NSException raise:FastCodingException format:@"Unable to encode NSValue data of type %@", @(type)];
    }
}

@end

