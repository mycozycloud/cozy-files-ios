//
//  CCAppDelegate.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"

#define kDatabaseName @"cozyios"

@interface CCAppDelegate ()

@end

@implementation CCAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Get or create the database
    NSError *error;
    self.database = [[CBLManager sharedInstance] createDatabaseNamed:kDatabaseName
                                                               error:&error];
    
    if (!self.database) {
        [self showAlert:@"L'app n'a pas pu ouvrir la base de données."
                  error:error
                  fatal:YES];
    }
    
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
    exit(0);
}

#pragma mark - Database

- (void)setupReplicationWithCozyURLString:(NSString *)cozyURL
                              remoteLogin:(NSString *)remoteLogin
                           remotePassword:(NSString *)remotePassword
                                    error:(NSError *__autoreleasing *)error
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
    
    // Define validation
#warning FOR NOW
    [self.database defineValidation:@"allok" asBlock:VALIDATIONBLOCK({
        return YES;
    })];
    
    // Define local filter
    [self.database defineFilter:@"filesfilter"
                        asBlock:FILTERBLOCK({
        CBLDocument *doc = revision.document;
        if ([[doc valueForKey:@"_deleted"] boolValue])
            return YES;

        if ([doc valueForKey:@"docType"] &&
            ([[doc valueForKey:@"docType"] isEqualToString:@"File"]
            || [[doc valueForKey:@"docType"] isEqualToString:@"Folder"])) {
                return YES;
        }
        
        return NO;
    })];
    
    // Define database views
    CBLView* pathView = [self.database viewNamed: @"byPath"];
    [pathView setMapBlock: MAPBLOCK({
        id path = [doc objectForKey: @"path"];
        if (path) emit(path, doc);
    }) version: @"1.0"];
    
    // Actually set up the replication
    NSString *newCozyURL = [NSString stringWithFormat:@"https://%@/cozy", url.host];
    NSArray *repls = [self.database replicateWithURL:[NSURL URLWithString:newCozyURL]
                                         exclusively:YES];
    
    self.pull = repls.firstObject;
    self.pull.persistent = YES;
    self.pull.continuous = YES;
    
    self.push = repls.lastObject;
    self.push.persistent = YES;
    self.push.continuous = YES;
    
    // Set the filters
    self.pull.filter = @"filter/filesfilter";
    self.push.filter = @"filesfilter";
    
    // Monitor the progress
    [self.pull addObserver:self forKeyPath:@"completed" options:0 context:NULL];
    [self.push addObserver:self forKeyPath:@"completed" options:0 context:NULL];
    
    // Start the replications
    [self.pull start];
    [self.push start];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == self.pull || object == self.push) {
        unsigned completed = self.pull.completed + self.push.completed;
        unsigned total = self.pull.total + self.push.total;
        if (total > 0 && completed < total) {
            NSLog(@"REPLICATION COMPLETED : %f%%",
                  floorf((completed / (float)total)*100));
        }
    }
}


@end
