//
//  CCAppDelegate.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"

#define kDatabaseName @"cozy"

@implementation CCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Get or create the database
    NSError *error;
    self.database = [[CBLManager sharedInstance] createDatabaseNamed:kDatabaseName error:&error];
    
    if (!self.database) {
        [self showAlert:@"L'app n'a pas pu ouvrir la base de données." error:error fatal:YES];
    }
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Alerts

// Displays an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert:(NSString *)message error:(NSError *)error fatal:(BOOL)fatal
{
    if (error) {
        message = [NSString stringWithFormat:@"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:(fatal ? @"Erreur Fatale" : @"Erreur")
                                                        message:message
                                                       delegate:(fatal ? self : nil)
                                              cancelButtonTitle:(fatal ? @"Quitter" : @"Désolé")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    exit(0);
}

@end
