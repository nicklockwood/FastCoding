//
//  FastCoderTests.m
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//


#import <XCTest/XCTest.h>
#import "FastCoder.h"


@interface Model : NSObject <NSCopying>

@property (nonatomic, strong) NSString *text2;
@property (nonatomic, strong) NSString *textNew;
@property (nonatomic, strong) NSArray *array1;
@property (nonatomic, strong) NSArray *array2;

@end


@implementation Model

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[self class]])
    {
        Model *model = object;
        
        return
        ((!self.text2 && !model.text2) || [self.text2 isEqual:model.text2]) &&
        ((!self.textNew && !model.textNew) || [self.textNew isEqual:model.textNew]) &&
        ((!self.array1 && !model.array1) || [self.array1 isEqual:model.array1]) &&
        ((!self.array2 && !model.array2) || [self.array2 isEqual:model.array2]);
    }
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    Model *copy = [[Model allocWithZone:zone] init];
    copy.text2 = self.text2;
    copy.textNew = self.textNew;
    copy.array1 = self.array1;
    copy.array2 = self.array2;
    return copy;
}

- (id)awakeAfterFastCoding
{
    return [self copy];
}

@end


@interface FastCoderTests : XCTestCase

@end


@implementation FastCoderTests

- (void)testChangingModel
{
    //create model
    Model *model = [[Model alloc] init];
    model.text2 = @"foo";
    model.textNew = [NSMutableString stringWithString:@"bar"];
    model.array1 = @[@"foo", @"bar"];
    model.array2 = @[@1, @2];
    
    //save model
    NSData *data = [FastCoder dataWithRootObject:model];
    
    //load as new model
    Model *newModel = [FastCoder objectWithData:data];
    
    //check properties
    XCTAssertEqualObjects(model, newModel);
}

- (void)testAliasing
{
    __strong Model *model = [[Model alloc] init];
    model.array1 = @[@1, @2];
    model.array2 = model.array1;
    
    //seralialize
    NSData *data = [FastCoder dataWithRootObject:model];
    
    //load as new model
    model = [FastCoder objectWithData:data];
    
    //check properties
    XCTAssertNotNil(model);
    XCTAssertEqualObjects(model.array1, model.array2);
    XCTAssertEqual(model.array1, model.array2);
    
    //now make them different but equal
    model.array2 = @[@1, @2];
    
    //seralialize
    data = [FastCoder dataWithRootObject:model];
    
    //load as new model
    model = [FastCoder objectWithData:data];
    
    //check properties
    XCTAssertEqualObjects(model.array1, model.array2);
    XCTAssertNotEqual(model.array1, model.array2);
}

- (void)testAliasingWithSubstitution
{
    Model *model = [[Model alloc] init];
    NSArray *array = @[model, model];
    
    //seralialize
    NSData *data = [FastCoder dataWithRootObject:array];
    
    //deserialize
    array = [FastCoder objectWithData:data];
    
    //check properties
    XCTAssertEqual(array[0], array[1]);
}

- (void)testBootstrapping
{
    //create JSON with circular reference
    NSString *json = @"{ \"foo\": { \"$alias\": \"bar.1\" }, \"bar\": [ \"Goodbye\", \"Cruel\", \"World\" ] }";
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:NULL];
    
    //convert to FastCoded data
    data = [FastCoder dataWithRootObject:object];
    object = [FastCoder objectWithData:data];
    
    //check
    XCTAssertEqualObjects(object[@"foo"], object[@"bar"][1]);
}

- (void)testURLEncoding
{
    //create URL with circular reference
    NSURL *URL = [NSURL URLWithString:@"foobar" relativeToURL:[NSURL URLWithString:@"http://example.com"]];
    id input = @{@"a": URL, @"b": URL, @"c": URL, @"d": URL};
    
    //convert to FastCoded data
    NSData *data = [FastCoder dataWithRootObject:input];
    id output = [FastCoder objectWithData:data];
    
    //check
    XCTAssertEqualObjects(input, output);
}

- (void)testIndexSetEncoding
{
    //create index set
    NSIndexSet *input = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 99)];
    
    //convert to FastCoded data
    NSData *data = [FastCoder dataWithRootObject:input];
    id output = [FastCoder objectWithData:data];
  
    //check
    XCTAssertEqualObjects(input, output);
    
    //create mutable index set
    input = [NSMutableIndexSet indexSet];
    [(NSMutableIndexSet *)input addIndexesInRange:NSMakeRange(0, 30)];
    [(NSMutableIndexSet *)input addIndexesInRange:NSMakeRange(50, 80)];
    
    //convert to FastCoded data
    data = [FastCoder dataWithRootObject:input];
    output = [FastCoder objectWithData:data];
    
    //check
    XCTAssertEqualObjects(input, output);
    XCTAssertEqualObjects([output classForCoder], [NSMutableIndexSet class]);
}

@end
