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
            NSLog(@"%@", group.description);
            if (group) {
                [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop){
                    if (result) {
//                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSLog(@"ASSET %@", result);
//                            NSError *error;
//                            ALAssetRepresentation *representation = result.defaultRepresentation;
//                            NSString *path = [[NSUserDefaults standardUserDefaults]
//                                              objectForKey:[ccRemoteLoginKey copy]];
//                            
//                            NSLog(@"PATH %@", path);
//                            
//                            NSDictionary *binaryContents = @{@"docType" : @"Binary"};
//                            CBLDocument *binary = [[CCDBManager sharedInstance].database createDocument];
//                            [binary putProperties:binaryContents error:&error];
//                            CBLUnsavedRevision *rev = [binary newRevision];
//                            
//                            NSData *imageData = UIImagePNGRepresentation([UIImage imageWithCGImage:representation.fullResolutionImage]);
//                            [rev setAttachmentNamed:representation.filename withContentType:@"image/png" content:imageData];
//                            [rev save:&error];
//                            
//                            NSDictionary *fileContents =
//                            @{@"name" : representation.filename,
//                              @"path" : path,
//                              @"docType" : @"File",
//                              @"binary" : @{
//                                      @"file" : @{
//                                              @"id" : [binary.properties objectForKey:@"_id"],
//                                              @"rev" : [binary.properties objectForKey:@"_rev"]
//                                              }
//                                      }
//                              };
//                            CBLDocument *doc = [[CCDBManager sharedInstance].database createDocument];
//                            [doc putProperties:fileContents error:&error];
//                            
//                            if (error) {
//#warning HANDLE ERROR
//                                NSLog(@"ERROR %@", error);
//                            }
//
//                        });
                    }
                }];
            }
        }
        failureBlock:^(NSError *error){
#warning HANDLE ERROR
            NSLog(@"ERROR %@", error);
        }];
}

@end
