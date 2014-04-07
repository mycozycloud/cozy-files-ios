//
//  CCDBManager.h
//  Cozy Files
//
//  Created by William Archimede on 26/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

@import Foundation;

#import <CouchbaseLite/CouchbaseLite.h>

@interface CCDBManager : NSObject

/*! Retrieves or creates the singleton instance of CCDBManager.
 * \returns the shared instance of the db manager.
 */
+ (CCDBManager *)sharedInstance;

@property (strong, nonatomic) CBLDatabase *database;

// Replications
@property (strong, nonatomic) CBLReplication *push;
@property (strong, nonatomic) CBLReplication *pull;

/*! Initiates the database.
 */
- (void)initDB;

/*! Initiates the replications when starting the app.
 * \param cozyURL A string representing the url of the remote cozy
 * \param remoteLogin The login on the remote cozy
 * \param remotePassword The password on the remote cozy
 * \param remoteID The ID on the remote cozy
 */
- (void)setupReplicationWithCozyURLString:(NSString *)cozyURL
                              remoteLogin:(NSString *)remoteLogin
                           remotePassword:(NSString *)remotePassword
                                 remoteID:(NSString *)remoteID;

/*! Replicates a single binary document from/to the cozy to/from the device.
 * \param binaryID The ID of the binary document
 * \param isPull A boolean signaling if it is a pull or push replication
 * \returns A replication object for the binary document.
 */
- (CBLReplication *)setupFileReplicationForBinaryID:(NSString *)binaryID
                                               pull:(BOOL)isPull;

@end
