//
//  CCPhotoImporter.h
//  Cozy Files
//
//  Created by William Archimede on 28/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

@import Foundation;

@interface CCPhotoImporter : NSObject

/*! Retrieves or creates the singleton instance of CCErrorHandler.
 * \returns the shared instance of the error handler.
 */
+ (CCPhotoImporter *)sharedInstance;

/*! Checks that the user authorized access to the photos and starts the photo import.
 */
- (void)checkAuthorizationForImport;

/*! Initializes the monitoring of the reachability of the cozy via Wifi.
 */
- (void)startWifiReachabilityMonitoring;

@end
