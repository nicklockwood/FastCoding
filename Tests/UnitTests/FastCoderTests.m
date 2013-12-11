//
//  FastCoderTests.m
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import "FastCoderTests.h"
#import "FastCoder.h"


@interface Model : NSObject

@property (nonatomic, strong) NSString *text2;
@property (nonatomic, strong) NSString *textNew;
@property (nonatomic, strong) NSArray *array1;
@property (nonatomic, strong) NSArray *array2;

@end


@implementation Model

- (BOOL)isEqual:(Model *)object
{
    if ([object isKindOfClass:[self class]])
    {
        return
        ((!self.text2 && !object.text2) || [self.text2 isEqual:object.text2]) &&
        ((!self.textNew && !object.textNew) || [self.textNew isEqual:object.textNew]) &&
        ((!self.array1 && !object.array1) || [self.array1 isEqual:object.array1]) &&
        ((!self.array2 && !object.array2) || [self.array2 isEqual:object.array2]);
    }
    return NO;
}

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
    NSAssert([model isEqual:newModel], @"ChangingModel text failed");
}

- (void)testAliasing
{
    Model *model = [[Model alloc] init];
    model.array1 = @[@1, @2];
    model.array2 = model.array1;
    
    //seralialize
    NSData *data = [FastCoder dataWithRootObject:model];
    
    //load as new model
    model = [FastCoder objectWithData:data];
    
    //check properties
    NSAssert([model.array1 isEqualToArray:model.array2], @"Aliasing failed");
    NSAssert(model.array1 == model.array2, @"Aliasing failed");
    
    //now make them different but equal
    model.array2 = @[@1, @2];
    
    //seralialize
    data = [FastCoder dataWithRootObject:model];
    
    //load as new model
    model = [FastCoder objectWithData:data];
    
    //check properties
    NSAssert([model.array1 isEqualToArray:model.array2], @"Aliasing failed");
    NSAssert(model.array1 != model.array2, @"Aliasing failed");
}

@end