//
//  CCAppDelegate.h
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

@import UIKit;

#import <CouchbaseLite/CouchbaseLite.h>

#define kRemoteIDKey @"cozyFilesRemoteID"

// Appearance constants
#define kYellow [UIColor colorWithRed:254/255.0 green:136/255.0 blue:0 alpha:1]
#define kBlue [UIColor colorWithRed:27/255.0 green:171/255.0 blue:244/255.0 alpha:1]
#define kBorderWidth 0.8
#define kCornerRadius 5.0

@interface CCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CBLDatabase *database;

// Presistent replications
@property (strong, nonatomic) CBLReplication *push;
@property (strong, nonatomic) CBLReplication *pull;
// Used to initiate the persistent replications when starting the app
- (void)setupReplicationWithCozyURLString:(NSString *)cozyURL
                              remoteLogin:(NSString *)remoteLogin
                           remotePassword:(NSString *)remotePassword
                                 remoteID:(NSString *)remoteID;
// Used to replicate single binary documents
- (CBLReplication *)setupFileReplicationForBinaryID:(NSString *)binaryID;

@end
