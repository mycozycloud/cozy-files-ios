//
//  CCDBManager.m
//  Cozy Files
//
//  Created by William Archimede on 26/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

#import "CCDBManager.h"
#import "CCErrorHandler.h"
#import "CCConstants.h"

// Database
static const NSString *ccDBName = @"cozyios";

@implementation CCDBManager

/*
 * Singleton
 */
+ (CCDBManager *)sharedInstance
{
    // Static variable to hold the instance of the singleton
    static CCDBManager *_sharedInstance = nil;
    
    // Static variable which ensures that the initialization code
    // executes only once
    static dispatch_once_t oncePredicate;
    
    // Use GCD to execute only once the block which initializes the instance
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [CCDBManager new];
    });
    
    return _sharedInstance;
}

#pragma mark - Database

- (void)initDB
{
    NSError *error;
    self.database = [[CBLManager sharedInstance] databaseNamed:[ccDBName copy]
                                                         error:&error];
    
    if (!self.database) { // Bug : no db available nor created
        [[CCErrorHandler sharedInstance] presentError:error
                    withMessage:[ccErrorDBAccess copy]
                    fatal:YES];
    } else { // Ok then set the filters, the views and validation functions
        [self setDbFunctions];
    }
}

- (void)setDbFunctions
{
    // Retreive replications
#warning CHANGE THIS
    if (self.database.allReplications.count > 1) {
        self.pull = self.database.allReplications.firstObject;
        self.push = [self.database.allReplications objectAtIndex:1];
    }
    
    // Define validation, everything is accepted
    [self.database setValidationNamed:@"fileFolderBinary" asBlock:VALIDATIONBLOCK()];
    
    // Define database views
    CBLView *pathView = [self.database viewNamed: @"byPath"];
    [pathView setMapBlock: MAPBLOCK({
        id path = [doc objectForKey: @"path"];
        if (path) emit(path, doc);
    }) version: @"1.0"];
    
    CBLView *nameView = [self.database viewNamed: @"byName"];
    [nameView setMapBlock: MAPBLOCK({
        NSString *name = [doc objectForKey: @"name"];
        if (name) {
            // enumerating all substrings of the name of the doc
            for (int start=0; start<name.length; start++) {
                for (int end=start; end<name.length; end++) {
                    NSRange range;
                    range.location = start;
                    range.length = end - start + 1;
                    emit([name substringWithRange:range], doc);
                }
            }
        }
        
    }) version: @"1.0"];
    
    // Define filter for push replication
    [self.database setFilterNamed:@"filter"
                          asBlock:FILTERBLOCK({
        
        if ([revision isDeletion]) {
            return YES;
        }
        
        CBLDocument *doc = revision.document;
        
        if ([doc.properties valueForKey:@"docType"] &&
            ([[doc.properties valueForKey:@"docType"] isEqualToString:@"File"]
             || [[doc.properties valueForKey:@"docType"] isEqualToString:@"Folder"])) {
                return YES;
            }
        
        return NO;
    })];
}

#pragma mark - Replications

- (void)setupReplicationWithCozyURLString:(NSString *)cozyURL
                              remoteLogin:(NSString *)remoteLogin
                           remotePassword:(NSString *)remotePassword
                                 remoteID:(NSString *)remoteID
{
    NSURL *url = [NSURL URLWithString:cozyURL];
    
    // Set the credentials
    NSURLCredential *cred = [NSURLCredential credentialWithUser:remoteLogin
                                                       password:remotePassword
                                                    persistence:NSURLCredentialPersistencePermanent];
    
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:url.host
                                                                        port:443
                                                                    protocol:@"https"
                                                                       realm:nil
                                                        authenticationMethod:NSURLAuthenticationMethodHTMLForm]; // the only one that works
    [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:cred
                                                        forProtectionSpace:space];
    
    // Remember remoteID for later use
#warning CHANGE TO REMEMBER EVERYTHING
    [[NSUserDefaults standardUserDefaults] setObject:remoteID forKey:[ccRemoteIDKey copy]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Actually set up the two-way continuous replication
    NSURL *newCozyURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/cozy", url.host]];
    
    self.pull = [self.database createPullReplication:newCozyURL];
    self.pull.continuous = YES;
    
    self.push = [self.database createPushReplication:newCozyURL];
    self.push.continuous = YES;
    
    // Set the filter for the pull replication
    self.pull.filter = [NSString stringWithFormat:@"%@/filter", remoteID];
#warning Might change
    self.push.filter = @"filter";
    
    // Monitor the progress
    [self.pull addObserver:self forKeyPath:@"completedChangesCount" options:0 context:NULL];
    [self.push addObserver:self forKeyPath:@"completedChangesCount" options:0 context:NULL];
    
    // Start the replications
    [self.pull start];
#warning Might change
    [self.push start];
}

- (CBLReplication *)setupFileReplicationForBinaryID:(NSString *)binaryID
{
    // Set Pull replication, not continuous but persistent
    CBLReplication *binPull = [self.database createPullReplication:self.pull.remoteURL];
    [binPull setDocumentIDs:@[binaryID]];
    binPull.continuous = NO;
    
    // Start replication
    [binPull start];
    
    return binPull;
}

#pragma mark - Replication Monitoring

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    // PULL
    if (object == self.pull && self.pull.changesCount > 0) {
        if (self.pull.completedChangesCount < self.pull.changesCount) {
            NSLog(@"PULL REPLICATION COMPLETION : %f%%",
                  floorf((self.pull.completedChangesCount /
                          (float)self.pull.changesCount)*100));
        }
    }
    
    // PUSH
    if (object == self.push && self.push.changesCount > 0) {
        if (self.push.completedChangesCount < self.push.changesCount) {
            NSLog(@"PUSH REPLICATION COMPLETION : %f%%",
                  floorf((self.push.completedChangesCount /
                          (float)self.push.changesCount)*100));
        }
    }
}


@end
