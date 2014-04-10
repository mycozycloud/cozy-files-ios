//
//  CCPhotoImporter.m
//  Cozy Files
//
//  Created by William Archimede on 28/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCDBManager.h"
#import "CCConstants.h"
#import "CCErrorHandler.h"
#import "CCPhotoImporter.h"

@import AssetsLibrary;

@interface CCPhotoImporter ()

/*! Accesses the photo assets taken with the phone and stores their urls and 
 * creation date for later import.
 */
- (void)importPhotoAssets;

/*! Creates the db documents for the next photo to import and 
 * replicates them to the digidisk.
 */
- (void)replicatePhoto;

@end

@implementation CCPhotoImporter

/*
 * Singleton
 */
+ (CCPhotoImporter *)sharedInstance
{
    // Static variable to hold the instance of the singleton
    static CCPhotoImporter *_sharedInstance = nil;
    
    // Static variable which ensures that the initialization code
    // executes only once
    static dispatch_once_t oncePredicate;
    
    // Use GCD to execute only once the block which initializes the instance
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [CCPhotoImporter new];
    });
    
    return _sharedInstance;
}

- (void)start
{
    NSLog(@"START IMPORT");
    
    // Initialize the date reference to old times if it does not already exist
    // It will be needed for comparison with creation dates of assets
    // in order to import only those which were not already imported
    if (![[NSUserDefaults standardUserDefaults] objectForKey:[ccLastImportDateKey copy]]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:[ccLastImportDateKey copy]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    switch ([ALAssetsLibrary authorizationStatus]) {
        case ALAuthorizationStatusAuthorized:
            NSLog(@"AUTHORIZED PHOTO IMPORT");
            // Start import since it is already authorized
            [self importPhotoAssets];
            break;
        case ALAuthorizationStatusNotDetermined: {
            NSLog(@"AUTHORIZATION FOR PHOTO IMPORT NOT DETERMINED");
            ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
            [assetsLib enumerateGroupsWithTypes:ALAssetsGroupPhotoStream
                    usingBlock:^(ALAssetsGroup *group, BOOL *stop){
                        // The user authorized access, no really need to enumerate
                        // all groups now.
                        *stop = YES;
                        
//                        // Start importing photos
//                        [self importPhotoAssets];
                    }
                    failureBlock:^(NSError *error){
                        if (error.code == ALAssetsLibraryAccessUserDeniedError) {
                            [[CCErrorHandler sharedInstance] presentError:error withMessage:[ccErrorPhotoAccess copy] fatal:NO];
                        }else{
                            [[CCErrorHandler sharedInstance] presentError:error withMessage:[ccErrorDefault copy] fatal:NO];
                        }
                    }];
            break;
        }
        default:{
            NSError *error = [[NSError alloc] initWithDomain:ALAssetsLibraryErrorDomain code:ALAssetsLibraryAccessUserDeniedError userInfo:nil];
            [[CCErrorHandler sharedInstance] presentError:error withMessage:[ccErrorDefault copy] fatal:NO];
            break;
        }
    }
}

- (void)importPhotoAssets
{
    NSLog(@"IMPORT ASSETS");
    
    // Retrieve last import date for comparison
    NSDate *lastImportDate = [[NSUserDefaults standardUserDefaults] objectForKey:[ccLastImportDateKey copy]];
    
    ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
    // Iterate over groups of assets
    [assetsLib enumerateGroupsWithTypes:ALAssetsGroupAll
        usingBlock:^(ALAssetsGroup *group, BOOL *stop){
            if (group) {
                // Filter photo only
                [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                // Iterate over assets in group
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop){
                    if (result) {
                        // Get creation date of the asset for comparison with the last import date
                        NSDate *creationDate = [result valueForProperty:ALAssetPropertyDate];
                        
                        // If it is a photo created after the last import date,
                        // then add it to the assets to replicate array
                        if ([[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypePhoto]
                            && [lastImportDate compare:creationDate] == NSOrderedAscending) {
                            
                            NSMutableArray *photos = [[[NSUserDefaults standardUserDefaults] objectForKey:[ccPhotosWaitingForImport copy]] mutableCopy];
                            if (!photos) {
                                photos = [NSMutableArray new];
                            }
                            [photos addObject:@{@"date":creationDate,
                                @"url":[result.defaultRepresentation.url absoluteString]}];
                            [[NSUserDefaults standardUserDefaults] setObject:photos
                                    forKey:[ccPhotosWaitingForImport copy]];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        }
                    }
                    
                }];
            } else {
                // Sort the assets array by creation date
                NSMutableArray *photos = [[[NSUserDefaults standardUserDefaults] objectForKey:[ccPhotosWaitingForImport copy]] mutableCopy];
                [photos sortUsingComparator:^(id obj1, id obj2){
                    return [[obj1 objectForKey:@"date"] compare:[obj2 objectForKey:@"date"]];
                }];
                [[NSUserDefaults standardUserDefaults] setObject:photos
                                        forKey:[ccPhotosWaitingForImport copy]];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSLog(@"ITERATION OVER ASSETS IS OVER - %@", photos);
                
                // When iteration is over,
                // update the last import date to the most recent creation date
                [[NSUserDefaults standardUserDefaults] setObject:[photos.lastObject objectForKey:@"date"]
                    forKey:[ccLastImportDateKey copy]];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // Start replicate asset to digidisk
                [self replicatePhoto];
            }
        }
        failureBlock:^(NSError *error){
            [[CCErrorHandler sharedInstance] presentError:error
                                    withMessage:[ccErrorPhotoImport copy]
                                                    fatal:NO];
        }];
}

- (void)replicatePhoto
{
    NSLog(@"REPLICATE PHOTO");
    
    NSString *binID = [[NSUserDefaults standardUserDefaults] objectForKey:[ccBinaryWaitingForPush copy]];
    if (binID) {
        // There's already a binary waiting for push, so start its replication
        NSLog(@"BIN ID : %@", binID);
        [[CCDBManager sharedInstance] setupFileReplicationForBinaryIDs:@[binID]
                                                              observer:self
                                                                  pull:NO];
    } else {
        // Get the oldest asset and replicate it
        NSArray *photos = [[NSUserDefaults standardUserDefaults] objectForKey:[ccPhotosWaitingForImport copy]];
        // Retrieve asset URL
        NSURL *assetUrl = [NSURL URLWithString:[photos.firstObject objectForKey:@"url"]];
        ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
        [assetsLib assetForURL:assetUrl
                   resultBlock:^(ALAsset *asset){
                       if (asset) {
                           NSLog(@"ASSET %@", asset);
                           
                           // Retrieve name and image
                           ALAssetRepresentation *representation = asset.defaultRepresentation;
                           NSString *filename = representation.filename;
                           NSData *imageData = UIImageJPEGRepresentation([UIImage imageWithCGImage:representation.fullResolutionImage], 1.0);
                           
                           // Importation to couchbase takes place on the main queue
                           dispatch_async(dispatch_get_main_queue(), ^{
                               NSError *error;
                               
                               // Create the binary document
                               NSDictionary *binaryContents = @{@"docType" : @"Binary"};
                               CBLDocument *binary = [[CCDBManager sharedInstance].database createDocument];
                               [binary putProperties:binaryContents error:&error];
                               CBLUnsavedRevision *rev = [binary newRevision];
                               
                               // Set attachment to image
                               [rev setAttachmentNamed:@"file"
                                       withContentType:@"image/jpeg"
                                               content:imageData];
                               CBLSavedRevision *savedRev = [rev save:&error];
                               CBLAttachment *att = savedRev.attachments.firstObject;
                               
                               
                               NSString *path = [NSString stringWithFormat:@"/%@",[[NSUserDefaults standardUserDefaults]
                                                                                   objectForKey:[ccRemoteLoginKey copy]]];
                               
                               // Create the file document
                               NSDictionary *fileContents =
                               @{@"name" : filename,
                                 @"path" : path,
                                 @"docType" : @"File",
                                 @"size" : [NSNumber numberWithInt:(int)att.length],
                                 @"binary" : @{
                                         @"file" : @{
                                                 @"id" : [savedRev.properties objectForKey:@"_id"],
                                                 @"rev" : [savedRev.properties objectForKey:@"_rev"]
                                                 }
                                         }
                                 };
                               
                               CBLDocument *doc = [[CCDBManager sharedInstance].database createDocument];
                               [doc putProperties:fileContents error:&error];
                               
                               if (error) {
                                   [[CCErrorHandler sharedInstance] presentError:error
                                                                     withMessage:[ccErrorPhotoImport copy]
                                                                           fatal:NO];
                               } else {
                                   // Store the id of the binary waiting for push
                                   [[NSUserDefaults standardUserDefaults] setObject:[savedRev.properties objectForKey:@"_id"] forKey:[ccBinaryWaitingForPush copy]];
                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                   
                                   // Start a one shot replication to push the binary to the digidisk
                                   // that is effective only on wifi networks
                                   [[CCDBManager sharedInstance] setupFileReplicationForBinaryIDs:@[[savedRev.properties objectForKey:@"_id"]]
                                                                                         observer:self
                                                                                             pull:NO];
                               }
                               
                           });
                           
                           
                           
                       }
                   }
                  failureBlock:^(NSError *error){
                      [[CCErrorHandler sharedInstance] presentError:error
                                                        withMessage:[ccErrorPhotoImport copy]
                                                              fatal:NO];
                  }
         ];

    }
}

#pragma mark - Replication Monitoring

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[CBLReplication class]]) {
        CBLReplication *rep = (CBLReplication *)object;
        // PUSH
        if (rep.changesCount > 0 && rep.completedChangesCount < rep.changesCount) {
            NSLog(@"BIN PUSH REPLICATION COMPLETION : %f%%",
                      floorf((rep.completedChangesCount /
                              (float)rep.changesCount)*100));
        } else {
            NSLog(@"BIN PUSH REPLICATION COMPLETION DONE");
            [rep removeObserver:self forKeyPath:@"completedChangesCount"];
            NSString *binID = rep.documentIDs.firstObject;
            NSError *error;
            CBLDocument *binary = [[CCDBManager sharedInstance].database documentWithID:binID];
                
            // Remove the id from waiting for push storage and
            // asset from the ones waiting for import
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:[ccBinaryWaitingForPush copy]];
            NSMutableArray *photos = [[[NSUserDefaults standardUserDefaults] objectForKey:[ccPhotosWaitingForImport copy]] mutableCopy];
            [photos removeObjectAtIndex:0];
            [[NSUserDefaults standardUserDefaults] setObject:photos
                forKey:[ccPhotosWaitingForImport copy]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Purge the binary from the db
            [binary purgeDocument:&error];
                
            if (error) {
                [[CCErrorHandler sharedInstance] presentError:error
                        withMessage:[ccErrorDefault copy]
                                    fatal:NO];
            } else {
                // Continue importing photos
                [self replicatePhoto];
            }

        }
    }
}

@end
