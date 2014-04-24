//
//  CCCacheManager.m
//  Cozy Files
//
//  Created by William Archimede on 24/04/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCCacheManager.h"
#import "CCDBManager.h"
#import "CCConstants.h"
#import "CCErrorHandler.h"

static const int maxSize = 5000000; // in bytes
static const NSString *ccBinaryCacheKey = @"binaryCache";

@implementation CCCacheManager

#pragma mark - Singleton
/*
 * Singleton
 */
+ (CCCacheManager *)sharedInstance
{
    // Static variable to hold the instance of the singleton
    static CCCacheManager *_sharedInstance = nil;
    
    // Static variable which ensures that the initialization code
    // executes only once
    static dispatch_once_t oncePredicate;
    
    // Use GCD to execute only once the block which initializes the instance
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [CCCacheManager new];
    });
    
    return _sharedInstance;
}

#pragma mark - Cache

- (void)addBinaryToCacheForFileID:(NSString *)fileID
{
    NSLog(@"ADD TO CACHE FOR FILE %@", fileID);
    
    CBLDocument *file = [[CCDBManager sharedInstance].database existingDocumentWithID:fileID];
    NSString *binaryID = [[[file.properties valueForKey:@"binary"]
                           valueForKey:@"file"] valueForKey:@"id"];
    NSNumber *binSize = [file.properties valueForKey:@"size"];
    
    NSLog(@"BIN SIZE %i", [binSize intValue]);
    
    NSMutableOrderedSet *binaryCache = [NSMutableOrderedSet orderedSetWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:[ccBinaryCacheKey copy]]];
    
    NSLog(@"BINARY CACHE : %@", binaryCache);
    
    if (!binaryCache) {
        binaryCache = [NSMutableOrderedSet new];
    }
    
    [binaryCache addObject:@{@"binaryID":binaryID, @"size":binSize}];
    
    if (binaryCache.count > 2) {
        int cacheSize = 0;
        for (NSDictionary *binInfo in binaryCache) {
            cacheSize += [[binInfo objectForKey:@"size"] intValue];
        }
        
        NSLog(@"CACHE SIZE : %i", cacheSize);
        if (cacheSize > maxSize) {
            NSError *error;
            for (int i = 0; i < 2; i++) {
                binaryID = [binaryCache.firstObject objectForKey:@"binaryID"];
                CBLDocument *binary = [[CCDBManager sharedInstance].database existingDocumentWithID:binaryID];
                
                BOOL purged = [binary purgeDocument:&error];
                if (purged) {
                    NSLog(@"PURGED BIN %@", binaryID);
                }
                
                [binaryCache removeObjectAtIndex:0];
            }
            
            BOOL compacted = [[CCDBManager sharedInstance].database compact:&error];
            if (compacted) {
                NSLog(@"DATABASE COMPACTED");
            }
            
            if (error) {
                NSLog(@"CACHE ERROR : %@", error);
            }
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:[binaryCache array] forKey:[ccBinaryCacheKey copy]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


@end
