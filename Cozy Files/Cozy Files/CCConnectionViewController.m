//
//  CCViewController.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import "CCConstants.h"
#import "CCErrorHandler.h"
#import "CCDBManager.h"
#import "CCConnectionViewController.h"

@interface CCConnectionViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *cozyUrlTextField;
@property (weak, nonatomic) IBOutlet UITextField *cozyMDPTextField;
@property (weak, nonatomic) IBOutlet UITextField *remoteNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *welcomeLabel;
- (IBAction)okPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *connectionButton;

/*! Sends a request to get the credentials necessary to initiate the replications.
 * \param cozyURL The URL of the cozy
 * \param cozyPassword The password for this cozy
 * \param remoteName The name of the new device to sync
 */
- (void)sendGetCredentialsRequestWithCozyURLString:(NSString *)cozyURL
                                      cozyPassword:(NSString *)cozyPassword
                                        remoteName:(NSString *)remoteName;

/*! Enables or disables the connection form.
 */
- (void)enableForm:(BOOL)enabled;

/*! Sets the appearance of the elements of this view controller.
 */
- (void)setAppearance;
@end

@implementation CCConnectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Disable default swipe to go back
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
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
    // Preparing the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
                                    [NSURL URLWithString:
                                     [NSString stringWithFormat:
                                      @"%@/device/", cozyURL]]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    
    // Body
    NSDictionary *requestData = [NSDictionary dictionaryWithObjectsAndKeys:remoteName,
                                 @"login", @"phone", @"type", nil];
    // Into JSON
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:requestData
                                                       options:0
                                                         error:&error];
    if (error) {
        [[CCErrorHandler sharedInstance] presentError:error
            withMessage:[ccErrorDefault copy]
            fatal:NO];
        self.welcomeLabel.text = @"Veuillez vous connecter";
        [self enableForm:YES];
    } else { // Auth
        NSString *base64Auth = [[[NSString stringWithFormat:@"owner:%@", cozyPassword]
                                 dataUsingEncoding:NSUTF8StringEncoding]
                                base64EncodedStringWithOptions:0];
        NSString *authValue = [NSString stringWithFormat:@"Basic %@", base64Auth];

        [request setValue:authValue forHTTPHeaderField:@"Authorization"];
        
        // Prepare the cofiguration for the session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        [config setAllowsCellularAccess:YES];
        [config setHTTPAdditionalHeaders:@{
            @"Accept": @"application/json",
            @"Content-Type": @"application/json",
            @"Authorization": authValue
        }];
        // Create the session with the configuration
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        // Send the post request
        [[session uploadTaskWithRequest:request fromData:postData
            completionHandler:
                ^(NSData *data, NSURLResponse *response, NSError *error){
                    if (error) {
                        [[CCErrorHandler sharedInstance] presentError:error
                            withMessage:[ccErrorDefault copy]
                            fatal:NO];
                        self.welcomeLabel.text = @"Veuillez vous connecter";
                        [self enableForm:YES];
                    } else {
                        NSDictionary *resp = [NSJSONSerialization
                                            JSONObjectWithData:data
                                                options:0
                                                error:&error];
                        if (error) { // if deserialization error
                            [[CCErrorHandler sharedInstance] presentError:error
                                withMessage:[ccErrorDefault copy]
                                fatal:NO];
                            self.welcomeLabel.text = @"Veuillez vous connecter";
                            [self enableForm:YES];
                        } else { // if error coming from the cozy
                            if ([resp valueForKey:@"error"]) {
                                [[CCErrorHandler sharedInstance] populateError:&error
                                    withCode:1
                                    userInfo:nil];
                                [[CCErrorHandler sharedInstance] presentError:error
                                    withMessage:[resp valueForKey:@"msg"]
                                    fatal:NO];
                                self.welcomeLabel.text = @"Veuillez vous connecter";
                                [self enableForm:YES];
                            } else { // No error, then should setup replications
                                NSLog(@"RESPONSE %@ - %@ - %@",
                                      [resp valueForKey:@"login"],
                                      [resp valueForKey:@"password"],
                                      [resp valueForKey:@"id"]);
                                
                                [[CCDBManager sharedInstance] setupReplicationWithCozyURLString:
                                                    self.cozyUrlTextField.text
                                        remoteLogin:[resp valueForKey:@"login"]
                                    remotePassword:[resp valueForKey:@"password"]
                                            remoteID:[resp valueForKey:@"id"]];
                                
                                [self dismissViewControllerAnimated:YES
                                                         completion:nil];
                            }
                        }
                    }
                }] resume];
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

@end
