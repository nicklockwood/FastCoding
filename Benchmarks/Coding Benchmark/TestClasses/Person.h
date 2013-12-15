//
//  Person.h
//  Benchmark
//
//  Created by Nick Lockwood on 15/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Person : NSObject <NSCoding>

@property (nonatomic, assign) NSUInteger identifier;
@property (nonatomic, copy) NSString *guid;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, copy) NSString *balance;
@property (nonatomic, copy) NSString *picture;
@property (nonatomic, assign) NSUInteger age;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *gender;
@property (nonatomic, copy) NSString *company;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *about;
@property (nonatomic, copy) NSString *registered;
@property (nonatomic, assign) float latitude;
@property (nonatomic, assign) float longitude;
@property (nonatomic, copy) NSArray *tags;
@property (nonatomic, copy) NSArray *friends;
@property (nonatomic, copy) NSString *randomArrayItem;

@end
