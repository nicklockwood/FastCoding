//
//  main.m
//  FastCoding
//
//  Created by Nick Lockwood on 09/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FastCoder.h"


void LogLoading(NSString *, NSTimeInterval, NSTimeInterval, NSTimeInterval);
void LogLoading(NSString *name, NSTimeInterval start, NSTimeInterval loaded, NSTimeInterval parsed)
{
    NSLog(@"%@ loading: %.0f ms, parsing: %.0f ms, total: %.0f ms", name, (loaded - start) * 1000, (parsed - loaded) * 1000, (parsed - start) * 1000);
}

void LogSaving(NSString *, NSTimeInterval, NSTimeInterval, NSTimeInterval);
void LogSaving(NSString *name, NSTimeInterval start, NSTimeInterval written, NSTimeInterval saved)
{
    NSLog(@"%@ writing: %.0f ms, saving: %.0f ms, total: %.0f ms", name, (written - start) * 1000, (saved - written) * 1000, (saved - start) * 1000);
}
#import <QuartzCore/QuartzCore.h>


int main(__unused int argc, __unused const char * argv[])
{
    @autoreleasepool
    {
        NSString *testInputPath = @"/Users/nick/Dropbox/Open Source (GIT)/FastCoding/Benchmark/TestData.json";
        NSData *data = [NSData dataWithContentsOfFile:testInputPath];
        id object = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:NULL];
        
        NSString *JSONPath = [NSTemporaryDirectory() stringByAppendingString:@"test.json"];
        NSString *PLISTPath = [NSTemporaryDirectory() stringByAppendingString:@"test.plist"];
        NSString *KeyedArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.nscoded"];
        NSString *FastArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.fast"];

        CFTimeInterval start = CFAbsoluteTimeGetCurrent();
        
        //write json
        data = [NSJSONSerialization dataWithJSONObject:object options:(NSJSONWritingOptions)0 error:NULL];
        CFTimeInterval jsonWritten = CFAbsoluteTimeGetCurrent();
        
        //save json
        [data writeToFile:JSONPath atomically:NO];
        CFTimeInterval jsonSaved = CFAbsoluteTimeGetCurrent();
        LogSaving(@"JSON", start, jsonWritten, jsonSaved);
        
        //load json
        data = [NSData dataWithContentsOfFile:JSONPath];
        CFTimeInterval jsonLoaded = CFAbsoluteTimeGetCurrent();
        
        //parse json
        object = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:NULL];
        CFTimeInterval jsonParsed = CFAbsoluteTimeGetCurrent();
        LogLoading(@"JSON", jsonSaved, jsonLoaded, jsonParsed);
        
        //write binary plist
        data = [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        CFTimeInterval plistWritten = CFAbsoluteTimeGetCurrent();

        //save binary plist
        [data writeToFile:PLISTPath atomically:NO];
        CFTimeInterval plistSaved = CFAbsoluteTimeGetCurrent();
        LogSaving(@"Plist", jsonParsed, plistWritten, plistSaved);
        
        //load binary plist
        data = [NSData dataWithContentsOfFile:PLISTPath];
        CFTimeInterval plistLoaded = CFAbsoluteTimeGetCurrent();
        
        //parse binary plist
        NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
        object = [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:NULL];
        CFTimeInterval plistParsed = CFAbsoluteTimeGetCurrent();
        LogLoading(@"Plist", plistSaved, plistLoaded, plistParsed);
        
        //write keyed archive
        data = [NSKeyedArchiver archivedDataWithRootObject:object];
        CFTimeInterval keyedArchiveWritten = CFAbsoluteTimeGetCurrent();
        
        //save keyed archive
        [data writeToFile:KeyedArchivePath atomically:NO];
        CFTimeInterval keyedArchiveSaved = CFAbsoluteTimeGetCurrent();
        LogSaving(@"Keyed Archive", plistParsed, keyedArchiveWritten, keyedArchiveSaved);
        
        //load keyed archive
        data = [NSData dataWithContentsOfFile:KeyedArchivePath];
        CFTimeInterval keyedArchiveLoaded = CFAbsoluteTimeGetCurrent();
        
        //parse keyed archive
        object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        CFTimeInterval keyedArchiveParsed = CFAbsoluteTimeGetCurrent();
        LogLoading(@"Keyed Archive", keyedArchiveSaved, keyedArchiveLoaded, keyedArchiveParsed);
        
        //write fast archive
        data = [FastCoder dataWithRootObject:object];
        CFTimeInterval fastArchiveWritten = CFAbsoluteTimeGetCurrent();
        
        //save fast archive
        [data writeToFile:FastArchivePath atomically:NO];
        CFTimeInterval fastArchiveSaved = CFAbsoluteTimeGetCurrent();
        LogSaving(@"Fast Archive", keyedArchiveParsed, fastArchiveWritten, fastArchiveSaved);
        
        //load fast archive
        data = [NSData dataWithContentsOfFile:FastArchivePath];
        CFTimeInterval fastArchiveLoaded = CFAbsoluteTimeGetCurrent();
        
        //parse fast archive
        [FastCoder objectWithData:data];
        CFTimeInterval fastArchiveParsed = CFAbsoluteTimeGetCurrent();
        LogLoading(@"Fast Archive", fastArchiveSaved, fastArchiveLoaded, fastArchiveParsed);
    }
    
    return 0;
}

