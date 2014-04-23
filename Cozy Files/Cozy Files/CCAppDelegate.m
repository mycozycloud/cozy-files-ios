//
//  CCAppDelegate.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "SWRevealViewController.h"

#import "CCAppDelegate.h"
#import "CCConstants.h"
#import "CCErrorHandler.h"
#import "CCDBManager.h"
#import "CCPhotoImporter.h"

@interface CCAppDelegate ()
// Used for UX customization
- (void)setAppearance;
@end

@implementation CCAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Init or create the database
    [[CCDBManager sharedInstance] initDB];
    
    // Customize the appearance
    [self setAppearance];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /* Sent when the application is about to move from active to inactive state. 
     This can occur for certain types of temporary interruptions 
     (such as an incoming phone call or SMS message) or when the user quits
     the application and it begins the transition to the background state.
    Use this method to pause ongoing tasks, disable timers, 
     and throttle down OpenGL ES frame rates. Games should use this method 
     to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /* Use this method to release shared resources, save user data, 
     invalidate timers, and store enough application state information to restore 
     your application to its current state in case it is terminated later.
    If your application supports background execution, this method is called 
     instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /* Called as part of the transition from the background to the inactive state; 
     here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /* Restart any tasks that were paused (or not yet started) 
     while the application was inactive. 
     If the application was previously in the background, 
     optionally refresh the user interface.
     */
    
    // Start the photo import if the user is connected
    if ([[NSUserDefaults standardUserDefaults]
         objectForKey:[ccRemoteIDKey copy]]) {
        [[CCPhotoImporter sharedInstance] startWifiReachabilityMonitoring];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /* Called when the application is about to terminate. 
     Save data if appropriate. See also applicationDidEnterBackground:.
     */
    NSLog(@"APP TERMINATES");
}

#pragma mark - Appearance

- (void)setAppearance
{
    // StatusBar
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    // NavigationBar
    [[UINavigationBar appearance] setBackgroundColor:kBlue];
    [[UINavigationBar appearance] setBarTintColor:kBlue];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];

    
    // TextFields
    [[UITextField appearance] setTextColor:kYellow];
    [[UITextField appearance] setTintColor:kYellow];
    
    // ProgressBar
    [[UIProgressView appearance] setProgressTintColor:kYellow];
}


@end
