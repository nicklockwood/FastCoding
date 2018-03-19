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

- (void)testColorSpace
{
    NSColorSpace *cs = [NSColorSpace sRGBColorSpace];

    NSData *data1 = [NSKeyedArchiver archivedDataWithRootObject:cs];
    NSColorSpace *cs1 = [NSKeyedUnarchiver unarchiveObjectWithData:data1];
    
    NSData *data2 = [FastCoder dataWithRootObject:cs];
    NSColorSpace *cs2 = [FastCoder objectWithData:data2];
    
    //check
    XCTAssertEqualObjects(cs, cs1);
    XCTAssertEqualObjects(cs1, cs2);
}

@end

