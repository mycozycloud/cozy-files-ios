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
    [self enableForm:NO];
    
    [self sendGetCredentialsRequestWithCozyURLString:self.cozyUrlTextField.text
                                        cozyPassword:self.cozyMDPTextField.text
                                    remoteName:self.remoteNameTextField.text];
}

- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL
                                      cozyPassword:(NSString *)cozyPassword
                                        remoteName:(NSString *)remoteName
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:
                                     [NSString stringWithFormat:
                                      @"%@/device", cozyURL]]];
    
    NSDictionary *requestData = [NSDictionary dictionaryWithObjectsAndKeys:remoteName,
                                 @"login", nil];
    
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:requestData
                                                       options:0
                                                         error:&error];
    
    if (error) {
        [appDelegate showAlert:@"Une erreur s'est produite" error:error fatal:NO];
        self.welcomeLabel.text = @"Veuillez vous connecter";
        [self enableForm:YES];
    } else {
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
        } else {
            [self.progressView setHidden:YES];
            [self dismissViewControllerAnimated:YES completion:nil]; // TEST
        }
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
    // Colors
    UIColor *yellow = [UIColor colorWithRed:254/255.0
                                      green:136/255.0
                                       blue:0
                                      alpha:1];
    UIColor *blue = [UIColor colorWithRed:27/255.0
                                    green:171/255.0
                                     blue:244/255.0
                                    alpha:1];
    
    // TextFields
    [[UITextField appearance] setTextColor:yellow];
    [[UITextField appearance] setTintColor:yellow];
    
    CGFloat borderWidth = 0.8;
    CGFloat cornerRadius = 5.0;
    
    self.cozyUrlTextField.layer.borderColor = [yellow CGColor];
    self.cozyUrlTextField.layer.borderWidth = borderWidth;
    self.cozyUrlTextField.layer.cornerRadius = cornerRadius;
    
    self.cozyMDPTextField.layer.borderColor = [yellow CGColor];
    self.cozyMDPTextField.layer.borderWidth = borderWidth;
    self.cozyMDPTextField.layer.cornerRadius = cornerRadius;
    
    self.remoteNameTextField.layer.borderColor = [yellow CGColor];
    self.remoteNameTextField.layer.borderWidth = borderWidth;
    self.remoteNameTextField.layer.cornerRadius = cornerRadius;
    
    // Buttons
    [[UIButton appearance] setBackgroundColor:blue];
    [[UIButton appearance] setTintColor:[UIColor whiteColor]];
    self.connectionButton.layer.cornerRadius = cornerRadius;
    
    // ProgressBar
    [[UIProgressView appearance] setProgressTintColor:blue];
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
    if (error) {
        [appDelegate showAlert:@"Une erreur s'est produite"
                         error:error
                         fatal:NO];
        self.welcomeLabel.text = @"Veuillez vous connecter";
        [self enableForm:YES];
    } else {
        if ([resp valueForKey:@"error"]) {
            error = [NSError errorWithDomain:@"Cozy" code:1 userInfo:nil];
            [appDelegate showAlert:[resp valueForKey:@"msg"]
                             error:error
                             fatal:NO];
            self.welcomeLabel.text = @"Veuillez vous connecter";
            [self enableForm:YES];
        } else {
            NSLog(@"RESPONSE %@ - %@ - %@", [resp valueForKey:@"login"],
                  [resp valueForKey:@"password"],
                  [resp valueForKey:@"id"]);
            
            [appDelegate setupReplicationWithCozyURLString:self.cozyUrlTextField.text
                                        remoteLogin:[resp valueForKey:@"login"]
                                remotePassword:[resp valueForKey:@"password"]
                                        remoteID:[resp valueForKey:@"id"]
                                                error:&error];
            if (error) {
                self.welcomeLabel.text = @"Veuillez vous connecter";
                [self enableForm:YES];
            } else {
                [appDelegate.push addObserver:self
                                   forKeyPath:@"completed"
                                      options:0
                                      context:NULL];
                [appDelegate.pull addObserver:self
                                   forKeyPath:@"completed"
                                      options:0
                                      context:NULL];
            }
        }
    }
}

@end
