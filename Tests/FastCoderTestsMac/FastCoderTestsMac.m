//
//  FastCoderTestsMac.m
//  FastCoderTestsMac
//
//  Created by Adam Wulf on 2/25/18.
//  Copyright © 2018 Charcoal Design. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import "FastCoder.h"

@interface FastCoderTestsMac : XCTestCase

@end

@implementation FastCoderTestsMac

- (void)testColorSpace{
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:[NSColorSpace sRGBColorSpace]];
    NSColorSpace *cs = [NSKeyedUnarchiver unarchiveObjectWithData:d];
    
    d = [FastCoder dataWithRootObject:[NSColorSpace sRGBColorSpace]];
    NSColorSpace *cs2 = [FastCoder objectWithData:d];
    
    //check
    XCTAssertEqualObjects(cs, cs2);
}


@end
