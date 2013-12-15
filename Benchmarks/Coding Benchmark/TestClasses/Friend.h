//
//  Friend.h
//  Benchmark
//
//  Created by Nick Lockwood on 15/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Friend : NSObject <NSCoding>

@property (nonatomic, assign) NSUInteger identifier;
@property (nonatomic, copy) NSString *name;

@end
