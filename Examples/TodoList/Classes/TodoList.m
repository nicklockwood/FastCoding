//
//  TodoList.m
//  TodoList
//
//  Created by Nick Lockwood on 15/04/2010.
//  Copyright 2010 Charcoal Design. All rights reserved.
//

#import "TodoList.h"
#import "TodoItem.h"
#import "FastCoder.h"


@implementation TodoList

#pragma mark -
#pragma mark Loading and saving

+ (NSString *)documentsDirectory
{	
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

+ (TodoList *)sharedList
{	
    static TodoList *sharedList = nil;
	if (sharedList == nil)
    {
        //attempt to load saved file
        NSString *path = [[self documentsDirectory] stringByAppendingPathComponent:@"TodoList.fast"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        sharedList = [FastCoder objectWithData:data];
        
        //if that fails, create a new, empty list
		if (sharedList == nil)
        {
            sharedList = [[TodoList alloc] init];
		}
	}
	return sharedList;
}

- (id)init
{
    if ((self = [super init]))
    {
        _items = [NSMutableArray array];
    }
    return self;
}

- (void)save
{
	NSString *path = [[[self class] documentsDirectory] stringByAppendingPathComponent:@"TodoList.fast"];
    NSData *data = [FastCoder dataWithRootObject:self];
    [data writeToFile:path atomically:YES];
}

@end
