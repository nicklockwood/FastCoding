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
  [FastCoder objectWithData:data];
  CFTimeInterval fastArchiveParsed = CFAbsoluteTimeGetCurrent();
  
  self.label.text = [@[LogSaving(@"Keyed Archive", start, keyedArchiveWritten, keyedArchiveSaved),
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
