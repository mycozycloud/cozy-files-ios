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

/*! Accesses the photos taken with the phone and imports them to the digidisk.
 */
- (void)importPhotos;

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
            [self importPhotos];
            break;
        case ALAuthorizationStatusNotDetermined: {
            NSLog(@"AUTHORIZATION FOR PHOTO IMPORT NOT DETERMINED");
            ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
            [assetsLib enumerateGroupsWithTypes:ALAssetsGroupPhotoStream
                    usingBlock:^(ALAssetsGroup *group, BOOL *stop){
                        // The user authorized access, no really need to enumerate
                        // all groups now.
                        *stop = YES;
                        
                        // Start importing photos
                        [self importPhotos];
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

- (void)importPhotos
{
    NSLog(@"IMPORT");
    
    // Restart binary push replications that were not finished
    NSArray *binaryIDs = [[NSUserDefaults standardUserDefaults] objectForKey:[ccBinaryIDsWaitingForPush copy]];
    if (binaryIDs && binaryIDs.count > 0) {
        NSLog(@"BINARIES TO PUSH - %@", binaryIDs);
        [[CCDBManager sharedInstance] setupFileReplicationForBinaryIDs:binaryIDs
                                                              observer:self
                                                                  pull:NO];
    }
    
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
                    // Get creation date of the asset for comparison with the last import date
                    NSDate *creationDate = [result valueForProperty:ALAssetPropertyDate];
                    
                    // If it is a photo created after the last import date,
                    // then import it to the Digidisk
                    if ([[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypePhoto]
                        && [lastImportDate compare:creationDate] == NSOrderedAscending) {
                        NSLog(@"ASSET %@", result);
                        
                        // Retrieve name and image
                        ALAssetRepresentation *representation = result.defaultRepresentation;
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
                                // Store the id of the binary in the array of binaries waiting for push
                                NSMutableArray *binaryIDs = [[[NSUserDefaults standardUserDefaults] objectForKey:[ccBinaryIDsWaitingForPush copy]] mutableCopy];
                                if (!binaryIDs) {
                                    binaryIDs = [NSMutableArray new];
                                }
                                [binaryIDs addObject:[savedRev.properties objectForKey:@"_id"]];
                                [[NSUserDefaults standardUserDefaults] setObject:binaryIDs forKey:[ccBinaryIDsWaitingForPush copy]];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                                
                                // Start a one shot replication to push the binary to the digidisk
                                // that is effective only on wifi networks
                                [[CCDBManager sharedInstance] setupFileReplicationForBinaryIDs:@[[savedRev.properties objectForKey:@"_id"]]
                                        observer:self
                                        pull:NO];
                            }

                        });
                    }
                }];
            } else {
                NSLog(@"ITERATION OVER ASSETS IS OVER");
                // When iteration is over,
                // update the last import date
                [[NSUserDefaults standardUserDefaults] setObject:[NSDate date]
                    forKey:[ccLastImportDateKey copy]];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
        failureBlock:^(NSError *error){
            [[CCErrorHandler sharedInstance] presentError:error
                                    withMessage:[ccErrorPhotoImport copy]
                                                    fatal:NO];
        }];
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
            for (NSString *binID in rep.documentIDs) {
                NSError *error;
                CBLDocument *binary = [[CCDBManager sharedInstance].database documentWithID:binID];
                
                // Remove the id from the array of binaries waiting for push
                NSMutableArray *binaryIDs = [[[NSUserDefaults standardUserDefaults] objectForKey:[ccBinaryIDsWaitingForPush copy]] mutableCopy];
                [binaryIDs removeObject:[binary.properties objectForKey:@"_id"]];
                [[NSUserDefaults standardUserDefaults] setObject:binaryIDs forKey:[ccBinaryIDsWaitingForPush copy]];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // Purge the binary from the db
                [binary purgeDocument:&error];
                
                if (error) {
                    [[CCErrorHandler sharedInstance] presentError:error
                                            withMessage:[ccErrorDefault copy]
                                                fatal:NO];
                }
            }
        }
    }
}

@end
