//
//  TodoListAppDelegate.m
//  TodoList
//
//  Created by Nick Lockwood on 08/04/2010.
//  Copyright Charcoal Design 2010. All rights reserved.
//

#import "TodoListAppDelegate.h"
#import "TodoListViewController.h"

@implementation TodoListAppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application
{    
    // Override point for customization after app launch    
    [_window addSubview:_viewController.view];
    [_window makeKeyAndVisible];
}

@end
