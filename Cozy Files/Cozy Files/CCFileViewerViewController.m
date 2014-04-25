//
//  CCFileViewerViewController.m
//  Cozy Files
//
//  Created by William Archimede on 08/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCConstants.h"
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

/*! Creates a local binary document and gets the associated attachment from the remote database.
 * \param binaryID The id of the binary document
 * \param binaryRev The _rev of the binary document, from the remote db point of view,
 *    and stored in the currentRev field. The binary document will locally have another _rev.
 */
- (void)fetchBinaryDocForID:(NSString *)binaryID andRev:(NSString *)binaryRev;

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
    
    NSLog(@"%@ - %@ - %@", fileBinaryRev, binary.currentRevisionID, [binary.properties objectForKey:@"currentRev"]);
    
    if ([binary.currentRevisionID isEqualToString:fileBinaryRev]
        || [[binary.properties objectForKey:@"currentRev"] isEqualToString:fileBinaryRev]) {
        // It exists and hasn't changed, so setup the view with the data
        NSLog(@"BINARY IS HERE");
        [self displayDataWithBinary:binary];
    } else { // It doesn't exist or has changed, so setup the replication to get the binary
        [self.activityIndicatorView startAnimating];
        NSLog(@"SETUP BINARY REPLICATION : %@", binaryID);
        
        [self fetchBinaryDocForID:binaryID andRev:fileBinaryRev];
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

- (void)fetchBinaryDocForID:(NSString *)binaryID andRev:(NSString *)binaryRev
{
    // Credentials for Basic auth
    NSURLCredential *cred = [[[NSURLCredentialStorage sharedCredentialStorage].allCredentials objectForKey:[NSURLCredentialStorage sharedCredentialStorage].allCredentials.allKeys.firstObject] objectForKey:[[NSUserDefaults standardUserDefaults] objectForKey:[ccRemoteLoginKey copy]]];
    NSString *login = [[NSUserDefaults standardUserDefaults] objectForKey:[ccRemoteLoginKey copy]];
    NSString *base64Auth = [[[NSString stringWithFormat:@"%@:%@", login, [cred password]]
                             dataUsingEncoding:NSUTF8StringEncoding]
                            base64EncodedStringWithOptions:0];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", base64Auth];
    
    NSString *cozyURLString = [[NSUserDefaults standardUserDefaults] objectForKey:[ccCozyURLKey copy]];
    NSURL *cozyURL = [NSURL URLWithString:cozyURLString];
    
    // Request for the attachment
    NSURL *attachReqURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/cozy/%@/file", cozyURL.host, binaryID]];
    
    // Preparing the request
    NSMutableURLRequest *attachReq = [NSMutableURLRequest requestWithURL:attachReqURL];
    [attachReq setHTTPMethod:@"GET"];
    [attachReq setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.URLCredentialStorage = [NSURLCredentialStorage sharedCredentialStorage];
    [config setAllowsCellularAccess:YES];
    [config setHTTPAdditionalHeaders:@{@"Authorization": authValue}];
    
    // Create the session with the configuration
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    [[session dataTaskWithRequest:attachReq
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
                    if (error) {
                        NSLog(@"ERROR WHILE FETCHING BINARY ATTACHMENT %@", error);
                    } else {
                        NSHTTPURLResponse *httpRes = (NSHTTPURLResponse *)response;
                        NSString *contentType = [httpRes.allHeaderFields objectForKey:@"Content-Type"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSError *error;
                            // Create the local binary document, with a custom revision
                            CBLDocument *binary = [[CCDBManager sharedInstance].database documentWithID:binaryID];
                            [binary putProperties:@{@"docType":@"Binary",
                                                    @"currentRev":binaryRev}
                                            error:&error];
                            // Add attachment
                            CBLUnsavedRevision *newRev = [binary newRevision];
                            [newRev setAttachmentNamed:@"file" withContentType:contentType content:data];
                            [newRev save:&error];
                            
                            if (error) {
                                NSLog(@"ERROR WHILE SAVING BINARY ATTACHMENT %@", error);
                            } else {
                                // Display the data
                                [self displayDataWithBinary:binary];
                                
                                // Add to the cache
                                [[CCCacheManager sharedInstance] addBinaryToCacheForFileID:self.fileID];
                            }
                        });
                    }
                }] resume];
}

- (void)displayDataWithBinary:(CBLDocument *)binary
{
    [self.activityIndicatorView stopAnimating];
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
