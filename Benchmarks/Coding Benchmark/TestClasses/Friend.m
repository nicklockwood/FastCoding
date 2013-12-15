//
//  Friend.m
//  Benchmark
//
//  Created by Nick Lockwood on 15/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "Friend.h"

@implementation Friend

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        self.identifier = [decoder decodeIntegerForKey:@"identifier"];
        self.name = [decoder decodeObjectForKey:@"name"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)self.identifier forKey:@"identifier"];
    [coder encodeObject:self.name forKey:@"name"];
}

@end
