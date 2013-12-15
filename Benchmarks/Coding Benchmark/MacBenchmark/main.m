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
        NSString *testInputPath = @"/Users/nick/Dropbox/Open Source (GIT)/FastCoding/Benchmarks/Coding Benchmark/TestData.json";
        NSData *data = [NSData dataWithContentsOfFile:testInputPath];
        id object = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:NULL];
        
        NSString *KeyedArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.nscoded"];
        NSString *FastArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.fast"];
        
        //bootstrap the JSON data into real objects
        data = [FastCoder dataWithRootObject:object];
        object = [FastCoder objectWithData:data];
        
        CFTimeInterval start = CFAbsoluteTimeGetCurrent();
        
        //write keyed archive
        data = [NSKeyedArchiver archivedDataWithRootObject:object];
        CFTimeInterval keyedArchiveWritten = CFAbsoluteTimeGetCurrent();
        
        //save keyed archive
        [data writeToFile:KeyedArchivePath atomically:NO];
        CFTimeInterval keyedArchiveSaved = CFAbsoluteTimeGetCurrent();
        LogSaving(@"Keyed Archive", start, keyedArchiveWritten, keyedArchiveSaved);
        
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

