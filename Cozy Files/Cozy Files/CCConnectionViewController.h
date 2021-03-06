//
//  CCViewController.h
//  Cozy Files
//
//  Created by William Archimede on 23/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCConnectionViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *cozyUrlTextField;
@property (weak, nonatomic) IBOutlet UITextField *cozyMDPTextField;
@property (weak, nonatomic) IBOutlet UITextField *remoteNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *welcomeLabel;
- (IBAction)okPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *connectionButton;

@end
