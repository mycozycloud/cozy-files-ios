//
//  CCViewController.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import "CCAppDelegate.h"
#import "CCViewController.h"

@interface CCViewController () <NSURLConnectionDataDelegate>
@property (strong, nonatomic) NSMutableData *responseData;

- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL cozyPassword:(NSString *)cozyPassword remoteName:(NSString *)remoteName;
@end

@implementation CCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.cozyUrlTextField.delegate = self;
    self.cozyMDPTextField.delegate = self;
    self.remoteNameTextField.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - TextField

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField isEqual:self.cozyUrlTextField]) {
        [self.cozyMDPTextField becomeFirstResponder];
    } else if ([textField isEqual:self.cozyMDPTextField]) {
        [self.remoteNameTextField becomeFirstResponder];
    } else {
        [self.remoteNameTextField resignFirstResponder];
    }
        
    return YES;
}

#pragma mark - Custom

- (IBAction)okPressed:(id)sender
{
    [self sendGetCredentialsRequestWithCozyURLString:self.cozyUrlTextField.text cozyPassword:self.cozyMDPTextField.text remoteName:self.remoteNameTextField.text];
}

- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL cozyPassword:(NSString *)cozyPassword remoteName:(NSString *)remoteName
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/apps/files/remotes", cozyURL]]];
    
    NSDictionary *requestData = [NSDictionary dictionaryWithObjectsAndKeys:remoteName, @"login", nil];
    
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:requestData options:0 error:&error];
    
    if (error) {
        CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
    } else {
        NSString *base64Auth = [[[NSString stringWithFormat:@"owner:%@", cozyPassword] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", base64Auth];
        
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:authValue forHTTPHeaderField:@"Authorization"];
        [request setValue:cozyPassword forHTTPHeaderField:@"X-Auth-Token"];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:postData];
        
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [connection start];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (object == appDelegate.pull || object == appDelegate.push) {
        unsigned completed = appDelegate.pull.completed + appDelegate.push.completed;
        unsigned total = appDelegate.pull.total + appDelegate.push.total;
        if (total > 0 && completed < total) {
            [self.progressView setHidden:NO];
            [self.progressView setProgress: (completed / (float)total)];
            NSLog(@"completed : %f", (completed / (float)total));
        } else {
            [self.progressView setHidden:YES];
        }
    }
}

#pragma mark - Connection

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSError *error;
    NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:self.responseData options:0 error:&error];
    if (error) {
        [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
    } else {
        if ([resp valueForKey:@"error"]) {
            error = [NSError errorWithDomain:@"Cozy" code:1 userInfo:nil];
            [appDelegate showAlert:[resp valueForKey:@"msg"] error:error fatal:NO];
        } else {
            [appDelegate setupReplicationWithCozyURLString:self.cozyUrlTextField.text remoteLogin:[resp valueForKey:@"login"] remotePassword:[resp valueForKey:@"password"] error:&error];
            if (!error) {
                [appDelegate.push addObserver:self forKeyPath:@"completed" options:0 context:NULL];
                [appDelegate.pull addObserver:self forKeyPath:@"completed" options:0 context:NULL];
            }
        }
    }
}

@end
