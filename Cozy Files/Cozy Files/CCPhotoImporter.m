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
#import "CCPhotoImporter.h"

@import AssetsLibrary;

@interface CCPhotoImporter ()

/*! Accesses the photos taken with the phone and imports to the digidisk.
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
    
    switch ([ALAssetsLibrary authorizationStatus]) {
        case ALAuthorizationStatusAuthorized:
            NSLog(@"AUTHORIZED PHOTO IMPORT");
            [self importPhotos];
            break;
        case ALAuthorizationStatusNotDetermined: {
            NSLog(@"AUTHORIZATION FOR PHOTO IMPORT NOT DETERMINED");
            ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
            [assetsLib enumerateGroupsWithTypes:ALAssetsGroupPhotoStream
                    usingBlock:^(ALAssetsGroup *group, BOOL *stop){
                        // The user authorized access, no really need to enumerate
                        // all groups.
                        *stop = YES;
                        // And start importing photos
                        [self importPhotos];
                    }
                    failureBlock:^(NSError *error){
#warning HANDLE ERROR
                        if (error.code == ALAssetsLibraryAccessUserDeniedError) {
                            NSLog(@"user denied access, code: %i",error.code);
                        }else{
                            NSLog(@"Other error code: %i",error.code);
                        }
                    }];
            break;
        }
        default:
#warning HANDLE ERROR
            break;
    }
}

- (void)importPhotos
{
    NSLog(@"IMPORT IMPORT");
    
    ALAssetsLibrary *assetsLib = [ALAssetsLibrary new];
    [assetsLib enumerateGroupsWithTypes:ALAssetsGroupAll
        usingBlock:^(ALAssetsGroup *group, BOOL *stop){
            NSLog(@"GROUP %@", group.description);
            if (group) {
                [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop){
                    if ([[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypePhoto]) {
                        NSLog(@"ASSET %@", result);
                        
                        ALAssetRepresentation *representation = result.defaultRepresentation;
                        NSString *filename = representation.filename;
                        NSData *imageData = UIImageJPEGRepresentation([UIImage imageWithCGImage:representation.fullResolutionImage], 1.0);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSError *error;
                            NSDictionary *binaryContents = @{@"docType" : @"Binary"};
                            CBLDocument *binary = [[CCDBManager sharedInstance].database createDocument];
                            [binary putProperties:binaryContents error:&error];
                            CBLUnsavedRevision *rev = [binary newRevision];
                            
                            
                            [rev setAttachmentNamed:@"file"
                                    withContentType:@"image/jpeg"
                                            content:imageData];
                            CBLSavedRevision *savedRev = [rev save:&error];
                            
                            NSString *path = [NSString stringWithFormat:@"/%@",[[NSUserDefaults standardUserDefaults]
                                objectForKey:[ccRemoteLoginKey copy]]];
                            
                            NSDictionary *fileContents =
                            @{@"name" : filename,
                              @"path" : path,
                              @"docType" : @"File",
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
#warning HANDLE ERROR
                                NSLog(@"ERROR %@", error);
                            } else {
                                // Start a one shot replication to push the binary to cozy
                                CBLReplication *rep = [[CCDBManager sharedInstance] setupFileReplicationForBinaryID:[savedRev.properties objectForKey:@"_id"] pull:NO];
                                [rep addObserver:self forKeyPath:@"completedChangesCount" options:0 context:NULL];
                            }

                        });
                    }
                }];
            }
        }
        failureBlock:^(NSError *error){
#warning HANDLE ERROR
            NSLog(@"ERROR %@", error);
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
                [binary purgeDocument:&error];
                
                if (error) {
#warning HANDLE ERROR
                    NSLog(@"ERROR %@", error);
                }
            }
        }
    }
}

@end
