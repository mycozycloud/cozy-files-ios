//
//  CCEditionViewController.h
//  Cozy Files
//
//  Created by William Archimede on 18/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CBLDocument;

@interface CCEditionViewController : UIViewController <UITextFieldDelegate>
@property (strong, nonatomic) CBLDocument *doc;
@property (weak, nonatomic) IBOutlet UITextField *docNameTextField;
- (IBAction)renamePressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;
@end
