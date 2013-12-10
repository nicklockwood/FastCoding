//
//  ViewController.m
//  FastCodingTest
//
//  Created by Nick Lockwood on 09/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "FastCoder.h"


@interface ViewController ()

@property (nonatomic, strong) IBOutlet UILabel *label;

@end


@implementation ViewController

NSString *LogLoading(NSString *name, NSTimeInterval start, NSTimeInterval loaded, NSTimeInterval parsed)
{
    return [NSString stringWithFormat:@"%@ loading: %.0f ms, parsing: %.0f ms, total: %.0f ms", name, (loaded - start) * 1000, (parsed - loaded) * 1000, (parsed - start) * 1000];
}

NSString *LogSaving(NSString *name, NSTimeInterval start, NSTimeInterval written, NSTimeInterval saved)
{
    return [NSString stringWithFormat:@"%@ writing: %.0f ms, saving: %.0f ms, total: %.0f ms", name, (written - start) * 1000, (saved - written) * 1000, (saved - start) * 1000];
}

- (IBAction)runBenchmark
{
    NSString *testInputPath = [[NSBundle mainBundle] pathForResource:@"TestData" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:testInputPath];
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    
    NSString *JSONPath = [NSTemporaryDirectory() stringByAppendingString:@"test.json"];
    NSString *PLISTPath = [NSTemporaryDirectory() stringByAppendingString:@"test.plist"];
    NSString *KeyedArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.nscoded"];
    NSString *FastArchivePath = [NSTemporaryDirectory() stringByAppendingString:@"test.fast"];
    
    CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    
    //write json
    data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    CFTimeInterval jsonWritten = CFAbsoluteTimeGetCurrent();
    
    //save json
    [data writeToFile:JSONPath atomically:NO];
    CFTimeInterval jsonSaved = CFAbsoluteTimeGetCurrent();
    
    //load json
    data = [NSData dataWithContentsOfFile:JSONPath];
    CFTimeInterval jsonLoaded = CFAbsoluteTimeGetCurrent();
    
    //parse json
    object = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    CFTimeInterval jsonParsed = CFAbsoluteTimeGetCurrent();
    
    //write binary plist
    data = [NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    CFTimeInterval plistWritten = CFAbsoluteTimeGetCurrent();
    
    //save binary plist
    [data writeToFile:PLISTPath atomically:NO];
    CFTimeInterval plistSaved = CFAbsoluteTimeGetCurrent();
    
    //load binary plist
    data = [NSData dataWithContentsOfFile:PLISTPath];
    CFTimeInterval plistLoaded = CFAbsoluteTimeGetCurrent();
    
    //parse binary plist
    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    object = [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:NULL];
    CFTimeInterval plistParsed = CFAbsoluteTimeGetCurrent();
    
    //write keyed archive
    data = [NSKeyedArchiver archivedDataWithRootObject:object];
    CFTimeInterval keyedArchiveWritten = CFAbsoluteTimeGetCurrent();
    
    //save keyed archive
    [data writeToFile:KeyedArchivePath atomically:NO];
    CFTimeInterval keyedArchiveSaved = CFAbsoluteTimeGetCurrent();
    
    //load keyed archive
    data = [NSData dataWithContentsOfFile:KeyedArchivePath];
    CFTimeInterval keyedArchiveLoaded = CFAbsoluteTimeGetCurrent();
    
    //parse keyed archive
    object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    CFTimeInterval keyedArchiveParsed = CFAbsoluteTimeGetCurrent();
    
    //write fast archive
    data = [FastCoder dataWithRootObject:object];
    CFTimeInterval fastArchiveWritten = CFAbsoluteTimeGetCurrent();
    
    //save fast archive
    [data writeToFile:FastArchivePath atomically:NO];
    CFTimeInterval fastArchiveSaved = CFAbsoluteTimeGetCurrent();
    
    //load fast archive
    data = [NSData dataWithContentsOfFile:FastArchivePath];
    CFTimeInterval fastArchiveLoaded = CFAbsoluteTimeGetCurrent();
    
    //parse fast archive
    object = [FastCoder objectWithData:data];
    CFTimeInterval fastArchiveParsed = CFAbsoluteTimeGetCurrent();
    
    self.label.text = [@[LogSaving(@"JSON", start, jsonWritten, jsonSaved),
                         LogLoading(@"JSON", jsonSaved, jsonLoaded, jsonParsed),
                         LogSaving(@"Plist", jsonParsed, plistWritten, plistSaved),
                         LogLoading(@"Plist", plistSaved, plistLoaded, plistParsed),
                         LogSaving(@"Keyed Archive", plistParsed, keyedArchiveWritten, keyedArchiveSaved),
                         LogLoading(@"Keyed Archive", keyedArchiveSaved, keyedArchiveLoaded, keyedArchiveParsed),
                         LogSaving(@"Fast Archive", keyedArchiveParsed, fastArchiveWritten, fastArchiveSaved),
                         LogLoading(@"Fast Archive", fastArchiveSaved, fastArchiveLoaded, fastArchiveParsed)] componentsJoinedByString:@"\n"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self runBenchmark];
}

@end
