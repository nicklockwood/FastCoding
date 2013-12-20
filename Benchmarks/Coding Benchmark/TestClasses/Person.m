//
//  Person.m
//  Benchmark
//
//  Created by Nick Lockwood on 15/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "Person.h"

@implementation Person

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        self.identifier = [decoder decodeIntegerForKey:@"identifier"];
        self.guid = [decoder decodeObjectForKey:@"guid"];
        self.isActive = [decoder decodeBoolForKey:@"isActive"];
        self.balance = [decoder decodeObjectForKey:@"balance"];
        self.picture = [decoder decodeObjectForKey:@"picture"];
        self.age = [decoder decodeIntegerForKey:@"age"];
        self.name = [decoder decodeObjectForKey:@"name"];
        self.gender = [decoder decodeObjectForKey:@"gender"];
        self.company = [decoder decodeObjectForKey:@"company"];
        self.email = [decoder decodeObjectForKey:@"email"];
        self.phone = [decoder decodeObjectForKey:@"phone"];
        self.address = [decoder decodeObjectForKey:@"address"];
        self.about = [decoder decodeObjectForKey:@"about"];
        self.registered = [decoder decodeObjectForKey:@"registered"];
        self.latitude = [decoder decodeFloatForKey:@"latitude"];
        self.longitude = [decoder decodeFloatForKey:@"longitude"];
        self.tags = [decoder decodeObjectForKey:@"tags"];
        self.friends = [decoder decodeObjectForKey:@"friends"];
        self.randomArrayItem = [decoder decodeObjectForKey:@"randomArrayItem"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)self.identifier forKey:@"identifier"];
    [coder encodeObject:self.guid forKey:@"guid"];
    [coder encodeBool:self.isActive forKey:@"isActive"];
    [coder encodeObject:self.balance forKey:@"balance"];
    [coder encodeObject:self.picture forKey:@"picture"];
    [coder encodeInteger:(NSInteger)self.age forKey:@"age"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.gender forKey:@"gender"];
    [coder encodeObject:self.company forKey:@"company"];
    [coder encodeObject:self.email forKey:@"email"];
    [coder encodeObject:self.phone forKey:@"phone"];
    [coder encodeObject:self.address forKey:@"address"];
    [coder encodeObject:self.about forKey:@"about"];
    [coder encodeObject:self.registered forKey:@"registered"];
    [coder encodeFloat:self.latitude forKey:@"latitude"];
    [coder encodeFloat:self.longitude forKey:@"longitude"];
    [coder encodeObject:self.tags forKey:@"tags"];
    [coder encodeObject:self.friends forKey:@"friends"];
    [coder encodeObject:self.randomArrayItem forKey:@"randomArrayItem"];
}

#if !__has_feature(objc_arc)

- (void)dealloc
{
    [_guid release];
    [_balance release];
    [_picture release];
    [_name release];
    [_gender release];
    [_company release];
    [_email release];
    [_phone release];
    [_address release];
    [_about release];
    [_registered release];
    [_tags release];
    [_friends release];
    [_randomArrayItem release];
    [super dealloc];
}

#endif

@end
