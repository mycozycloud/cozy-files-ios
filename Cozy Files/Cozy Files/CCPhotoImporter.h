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

/*! Starts the photo import.
 */
- (void)start;

@end
