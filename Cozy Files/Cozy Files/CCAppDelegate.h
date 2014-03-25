//
//  CCAppDelegate.h
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

@import UIKit;

#import <CouchbaseLite/CouchbaseLite.h>

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
