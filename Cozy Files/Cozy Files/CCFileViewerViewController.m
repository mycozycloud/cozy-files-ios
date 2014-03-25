//
//  CCFileViewerViewController.m
//  Cozy Files
//
//  Created by William Archimede on 08/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"
#import "CCFileViewerViewController.h"
#import "CCErrorHandler.h"

@interface CCFileViewerViewController ()
@property (strong, nonatomic) CBLReplication *pull;
- (void)displayDataWithBinary:(CBLDocument *)binary;
- (void)removeBinary;
@property (assign, nonatomic) BOOL isToRemove;
@end

@implementation CCFileViewerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    [self.imgView setHidden:YES];
    [self.txtView setHidden:YES];
    
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    
    self.isToRemove = NO;
    
    // First, get the File document
    CBLDocument *file = [appDelegate.database documentWithID:self.fileID];
    
    // Set the title
    self.title = [file.properties valueForKey:@"name"];
    
    // Then, check whether the binary exists locally and has changed
    NSString *binaryID = [[[file.properties valueForKey:@"binary"]
                           valueForKey:@"file"] valueForKey:@"id"];
    CBLDocument *binary = [appDelegate.database documentWithID:binaryID];
    
    NSString *fileBinaryRev = [[[file.properties valueForKey:@"binary"]
                               valueForKey:@"file"] valueForKey:@"rev"];
    
    NSLog(@"%@ - %@", fileBinaryRev, binary.currentRevisionID);
    
    if ([binary.currentRevisionID isEqualToString:fileBinaryRev]) { // It exists and hasn't changed, so setup the view with the data
        NSLog(@"BINARY IS HERE");
        [self displayDataWithBinary:binary];
    } else { // It doesn't exist or has changed, so setup the replication to get the binary
        NSLog(@"SETUP BINARY REPLICATION : %@", binaryID);
        NSError *error;
        [binary purgeDocument:&error];

        if (error) {
            NSLog(@"ERREUR - %@", error);
        }
    
        self.pull = [appDelegate setupFileReplicationForBinaryID:binaryID];
        
        // Pull monitoring
        [self.pull addObserver:self forKeyPath:@"completedChangesCount" options:0 context:NULL];
    }
    
    // Trash button
    [self.trashButton setTarget:self];
    [self.trashButton setAction:@selector(removeBinary)];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (self.isToRemove) { // Purge the binary when the view disappeared
        NSError *error;
        
        CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                       delegate];
        [self.pull stop];
        
        CBLDocument *file = [appDelegate.database documentWithID:self.fileID];
        
        NSString *binaryID = [[[file.properties valueForKey:@"binary"]
                               valueForKey:@"file"] valueForKey:@"id"];
        CBLDocument *binary = [appDelegate.database documentWithID:binaryID];
        
        [binary purgeDocument:&error];
        
        if (error) {
            [[CCErrorHandler sharedInstance] presentError:error
                withMessage:@"Une erreur est survenue"
                fatal:NO];
        }
        
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Cutsom

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSLog(@"MONITORING BINARY REPLICATION");
    
    if (object == self.pull) {
        NSLog(@"BINARY LOADING...");
        unsigned completed = self.pull.completedChangesCount;
        unsigned total = self.pull.changesCount;
        if (total > 0 && completed < total) {
            [self.progressView setHidden:NO];
            [self.progressView setProgress: (completed / (float)total)];
        } else {
            NSLog(@"BINARY REPLICATION DONE");
            [self.progressView setHidden:YES];
            // Display the data
            CBLDocument *doc = [appDelegate.database
                                documentWithID:self.pull.documentIDs.firstObject];
            [self displayDataWithBinary:doc];
        }
    }
}

- (void)displayDataWithBinary:(CBLDocument *)binary
{
    // Get attachments
    CBLAttachment *att = [[binary.currentRevision attachments] firstObject];
    
    NSString *extension = [[self.title componentsSeparatedByString:@"."] lastObject];
    
    // Display content based on file extension
    if ([extension isEqualToString:@"png"]) {
        [self.imgView setImage:[UIImage imageWithData:att.content]];
        self.imgView.hidden = NO;
    } else if ([extension isEqualToString:@"txt"]) {
        [self.txtView setText:[[NSString alloc] initWithData:att.content
                                        encoding:NSUTF8StringEncoding]];
        self.txtView.hidden = NO;
    }
        
}

- (void)removeBinary
{
    self.isToRemove = YES;
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
