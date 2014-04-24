//
//  CCFileViewerViewController.m
//  Cozy Files
//
//  Created by William Archimede on 08/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCErrorHandler.h"
#import "CCDBManager.h"
#import "CCCacheManager.h"
#import "CCFileViewerViewController.h"


@interface CCFileViewerViewController ()

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (weak, nonatomic) IBOutlet UITextView *txtView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rootButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;

@property (strong, nonatomic) CBLReplication *pull;

/*! Gets the binary file attachment and displays the content according to the
 * file extension.
 * \param binary The binary document holding the file to display
 */
- (void)displayDataWithBinary:(CBLDocument *)binary;

/*! Pops back to the root navigation controller.
 */
- (void)goBackToRoot;
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
    
    // Disable default swipe to go back
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    [self.imgView setHidden:YES];
    [self.txtView setHidden:YES];
    
    // First, get the File document
    CBLDocument *file = [[CCDBManager sharedInstance].database existingDocumentWithID:self.fileID];
    
    // Set the title
    self.title = [file.properties valueForKey:@"name"];
    
    // Then, check whether the binary exists locally and has changed
    NSString *binaryID = [[[file.properties valueForKey:@"binary"]
                           valueForKey:@"file"] valueForKey:@"id"];
    CBLDocument *binary = [[CCDBManager sharedInstance].database existingDocumentWithID:binaryID];
    
    NSString *fileBinaryRev = [[[file.properties valueForKey:@"binary"]
                               valueForKey:@"file"] valueForKey:@"rev"];
    
    NSLog(@"%@ - %@ - %@", fileBinaryRev, binary.currentRevisionID, binary);
    
    if ([binary.currentRevisionID isEqualToString:fileBinaryRev]) { // It exists and hasn't changed, so setup the view with the data
        NSLog(@"BINARY IS HERE");
        [self displayDataWithBinary:binary];
    } else { // It doesn't exist or has changed, so setup the replication to get the binary
        [self.activityIndicatorView startAnimating];
        NSLog(@"SETUP BINARY REPLICATION : %@", binaryID);
    
        self.pull = [[CCDBManager sharedInstance] setupFileReplicationForBinaryIDs:@[binaryID]
                                                            observer:self
                                                            pull:YES];
    }
    
    // Root button
    [self.rootButton setTarget:self];
    [self.rootButton setAction:@selector(goBackToRoot)];
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
            [self.activityIndicatorView stopAnimating];
            // Display the data
            CBLDocument *doc = [[CCDBManager sharedInstance].database
                                existingDocumentWithID:self.pull.documentIDs.firstObject];
            [self displayDataWithBinary:doc];
            
            // Add to the cache
            [[CCCacheManager sharedInstance] addBinaryToCacheForFileID:self.fileID];
            
            [self.pull removeObserver:self forKeyPath:@"completedChangesCount"];
            [self.pull removeObserver:self forKeyPath:@"changesCount"];
        }
    }
}

- (void)displayDataWithBinary:(CBLDocument *)binary
{
    // Get attachments
    CBLAttachment *att = [[binary.currentRevision attachments] firstObject];
    
    NSString *contentType = [[att.contentType componentsSeparatedByString:@"/"] firstObject];
    
    // Display content based on file extension
    if ([contentType isEqualToString:@"image"]) {
        [self.imgView setImage:[UIImage imageWithData:att.content]];
        self.imgView.hidden = NO;
    } else if ([contentType isEqualToString:@"text"]) {
        [self.txtView setText:[[NSString alloc] initWithData:att.content
                                        encoding:NSUTF8StringEncoding]];
        self.txtView.hidden = NO;
    }
        
}

- (void)goBackToRoot
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
