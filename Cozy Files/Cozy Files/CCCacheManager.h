//
//  CCCacheManager.h
//  Cozy Files
//
//  Created by William Archimede on 24/04/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

@import Foundation;

@interface CCCacheManager : NSObject

/*! Retrieves or creates the singleton instance of CCDBManager.
 * \returns the shared instance of the db manager.
 */
+ (CCCacheManager *)sharedInstance;

/*! Adds the id of a binary document and the size of its attachment to the set
 * of cached binary documents.
 * \param fileID The id of the file document related to the binary document to cache
 */
- (void)addBinaryToCacheForFileID:(NSString *)fileID;

@end
