//
//  CCViewController.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import "CCAppDelegate.h"
#import "CCConnectionViewController.h"

@interface CCConnectionViewController () <NSURLConnectionDataDelegate>
@property (strong, nonatomic) NSMutableData *responseData;

- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL
                                      cozyPassword:(NSString *)cozyPassword
                                        remoteName:(NSString *)remoteName;

- (void)enableForm:(BOOL)enabled;

- (void)setAppearance;
@end

@implementation CCConnectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.cozyUrlTextField.delegate = self;
    self.cozyMDPTextField.delegate = self;
    self.remoteNameTextField.delegate = self;
    
    [self setAppearance];
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
    self.welcomeLabel.text = @"Synchronisation en cours";
    [self enableForm:NO]; // Can't change the form values while syncing
    
    // Send connection request with the cozy in order to retrieve the remote credentials
    [self sendGetCredentialsRequestWithCozyURLString:self.cozyUrlTextField.text
                                        cozyPassword:self.cozyMDPTextField.text
                                    remoteName:self.remoteNameTextField.text];
}

- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL
                                      cozyPassword:(NSString *)cozyPassword
                                        remoteName:(NSString *)remoteName
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // Preparing the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:
                                     [NSString stringWithFormat:
                                      @"%@/device/", cozyURL]]];
    // Body
    NSDictionary *requestData = [NSDictionary dictionaryWithObjectsAndKeys:remoteName,
                                 @"login", nil];
    // Into JSON
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:requestData
                                                       options:0
                                                         error:&error];
    
    if (error) {
        [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
        self.welcomeLabel.text = @"Veuillez vous connecter";
        [self enableForm:YES];
    } else { // Auth
        NSString *base64Auth = [[[NSString stringWithFormat:@"owner:%@", cozyPassword]
                                 dataUsingEncoding:NSUTF8StringEncoding]
                                base64EncodedStringWithOptions:0];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", base64Auth];
        
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:authValue forHTTPHeaderField:@"Authorization"];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:postData];
        
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                      delegate:self];
        // send the request
        [connection start];
    }
}

- (void)enableForm:(BOOL)enabled
{
    self.cozyUrlTextField.enabled = enabled;
    self.cozyMDPTextField.enabled = enabled;
    self.remoteNameTextField.enabled = enabled;
    self.connectionButton.enabled = enabled;
}

- (void)setAppearance
{
    self.cozyUrlTextField.layer.borderColor = [kYellow CGColor];
    self.cozyUrlTextField.layer.borderWidth = kBorderWidth;
    self.cozyUrlTextField.layer.cornerRadius = kCornerRadius;
    
    self.cozyMDPTextField.layer.borderColor = [kYellow CGColor];
    self.cozyMDPTextField.layer.borderWidth = kBorderWidth;
    self.cozyMDPTextField.layer.cornerRadius = kCornerRadius;
    
    self.remoteNameTextField.layer.borderColor = [kYellow CGColor];
    self.remoteNameTextField.layer.borderWidth = kBorderWidth;
    self.remoteNameTextField.layer.cornerRadius = kCornerRadius;

    [self.connectionButton setBackgroundColor:kBlue];
    [self.connectionButton setTintColor:[UIColor whiteColor]];
    self.connectionButton.layer.cornerRadius = kCornerRadius;
}

#pragma mark - Connection

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
    self.welcomeLabel.text = @"Veuillez vous connecter";
    [self enableForm:YES];
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSError *error;
    NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:self.responseData
                                                         options:0
                                                           error:&error];
    if (error) { // if deserialization error
        [appDelegate showAlert:@"Une erreur s'est produite"
                         error:error
                         fatal:NO];
        self.welcomeLabel.text = @"Veuillez vous connecter";
        [self enableForm:YES];
    } else { // if error coming from the cozy
        if ([resp valueForKey:@"error"]) {
            error = [NSError errorWithDomain:kErrorDomain code:1 userInfo:nil];
            [appDelegate showAlert:[resp valueForKey:@"msg"]
                             error:error
                             fatal:NO];
            self.welcomeLabel.text = @"Veuillez vous connecter";
            [self enableForm:YES];
        } else { // No error, then should setup replications
            NSLog(@"RESPONSE %@ - %@ - %@", [resp valueForKey:@"login"],
                  [resp valueForKey:@"password"],
                  [resp valueForKey:@"id"]);
            
            [appDelegate setupReplicationWithCozyURLString:self.cozyUrlTextField.text
                                        remoteLogin:[resp valueForKey:@"login"]
                                remotePassword:[resp valueForKey:@"password"]
                                        remoteID:[resp valueForKey:@"id"]];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

@end
