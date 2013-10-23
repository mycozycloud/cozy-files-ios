//
//  CCViewController.m
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import "CCViewController.h"

@interface CCViewController ()

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

- (IBAction)okPressed:(id)sender
{
    NSLog(@"%@\n%@\n%@", self.cozyUrlTextField.text, self.cozyMDPTextField.text, self.remoteNameTextField.text);
}
@end
