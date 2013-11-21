//
//  CCFolderCreationViewController.h
//  Cozy Files
//
//  Created by William Archimede on 21/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCFolderCreationViewController : UIViewController <UITextFieldDelegate>
@property (strong, nonatomic) NSString *path;
@property (weak, nonatomic) IBOutlet UITextField *folderNameTextField;
- (IBAction)createPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;

@end
