//
//  CCAppDelegate.h
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CouchbaseLite/CouchbaseLite.h>

@interface CCAppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CBLDatabase *database;

// Utility method to display an alert error
- (void)showAlert:(NSString *)message error:(NSError *)error fatal:(BOOL)fatal;

// Replications
@property (strong, nonatomic) CBLReplication *push;
@property (strong, nonatomic) CBLReplication *pull;
- (void)setupReplicationWithCozyURLString:(NSString *)cozyURL remoteLogin:(NSString *)remoteLogin remotePassword:(NSString *)remotePassword error:(NSError **)error;

@end
