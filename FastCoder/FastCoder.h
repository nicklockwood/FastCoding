//
//  FastCoding.h
//  FastCoding
//
//  Created by Nick Lockwood on 09/12/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FastCoder : NSObject

+ (id)objectWithData:(NSData *)data;
+ (NSData *)dataWithRootObject:(id)object;

@end
