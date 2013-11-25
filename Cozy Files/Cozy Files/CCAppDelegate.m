//
//  CCAppDelegate.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "SWRevealViewController.h"

#import "CCAppDelegate.h"

// Database
#define kDatabaseName @"cozyios"

@interface CCAppDelegate ()
// Used to set filters, views and validation functions
- (void)setDbFunctions;
// Used for UX customization
- (void)setAppearance;
@end

@implementation CCAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Get or create the database
    NSError *error;
    self.database = [[CBLManager sharedInstance] databaseNamed:kDatabaseName
                                                               error:&error];
    
    if (!self.database) { // Bug : no db available nor created
        [self showAlert:@"L'app n'a pas pu ouvrir la base de données."
                  error:error
                  fatal:YES];
    } else { // Ok then set the filters, the views and validation functions
        [self setDbFunctions];
    }
    
    // Customize the appearance
    [self setAppearance];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /* Sent when the application is about to move from active to inactive state. 
     This can occur for certain types of temporary interruptions 
     (such as an incoming phone call or SMS message) or when the user quits
     the application and it begins the transition to the background state.
    Use this method to pause ongoing tasks, disable timers, 
     and throttle down OpenGL ES frame rates. Games should use this method 
     to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /* Use this method to release shared resources, save user data, 
     invalidate timers, and store enough application state information to restore 
     your application to its current state in case it is terminated later.
    If your application supports background execution, this method is called 
     instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /* Called as part of the transition from the background to the inactive state; 
     here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /* Restart any tasks that were paused (or not yet started) 
     while the application was inactive. 
     If the application was previously in the background, 
     optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /* Called when the application is about to terminate. 
     Save data if appropriate. See also applicationDidEnterBackground:.
     */
}

#pragma mark - Alerts

// Displays an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert:(NSString *)message error:(NSError *)error fatal:(BOOL)fatal
{
    if (error) {
        message = [NSString stringWithFormat:@"%@\n\n%@", message,
                   error.localizedDescription];
    }
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:(fatal ? @"Erreur Fatale" : @"Erreur")
                                    message:message
                                    delegate:(fatal ? self : nil)
                            cancelButtonTitle:(fatal ? @"Quitter" : @"Désolé")
                                    otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // If it's a fatal error, the app closes
    exit(0);
}

#pragma mark - Database

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
    [[NSUserDefaults standardUserDefaults] setObject:remoteID forKey:kRemoteIDKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Actually set up the two-way continuous and persistent replication
    NSString *newCozyURL = [NSString stringWithFormat:@"https://%@/cozy", url.host];
    NSArray *repls = [self.database replicationsWithURL:[NSURL URLWithString:newCozyURL]
                                         exclusively:YES];
    
    self.pull = repls.firstObject;
    self.pull.persistent = YES;
    self.pull.continuous = YES;
    
    self.push = repls.lastObject;
#warning Might change
    self.push.persistent = YES;
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
    CBLReplication *binPull = [[CBLReplication alloc]
                               initPullFromSourceURL:self.pull.remoteURL
                                            toDatabase:self.database];
    [binPull setDocumentIDs:@[binaryID]];
    binPull.persistent = NO;
    binPull.continuous = NO;
    
    // Start replication
    [binPull start];
    
    return binPull;
}

- (void)setDbFunctions
{
    // Retreive replications
    if (self.database.allReplications.count > 1) {
        self.pull = self.database.allReplications.firstObject;
        self.push = [self.database.allReplications objectAtIndex:1];
    }
    
    // Define validation
    [self.database setValidationNamed:@"fileFolderBinary" asBlock:VALIDATIONBLOCK({
        return YES;
    })];
    
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

#pragma mark - Appearance

- (void)setAppearance
{
    // TextFields
    [[UITextField appearance] setTextColor:kYellow];
    [[UITextField appearance] setTintColor:kYellow];
    
    // ProgressBar
    [[UIProgressView appearance] setProgressTintColor:kBlue];
}


@end
