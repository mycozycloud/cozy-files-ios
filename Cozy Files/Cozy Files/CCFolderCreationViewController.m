//
//  CCFolderCreationViewController.m
//  Cozy Files
//
//  Created by William Archimede on 21/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCConstants.h"
#import "CCErrorHandler.h"
#import "CCDBManager.h"
#import "CCFolderCreationViewController.h"

@interface CCFolderCreationViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *folderNameTextField;
- (IBAction)createPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;

/*! Sets the appearance of the elements of this view controller.
 */
- (void)setAppearance;

/*! Creates a folder with the current path.
 * \param name A string representing the name of the folder to create
 * \param error An error handled by the caller
 */
- (void)createFolderWithName:(NSString *)name error:(NSError *__autoreleasing *)error;
@end

@implementation CCFolderCreationViewController

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
    
    // Text Field
    self.folderNameTextField.delegate = self;
    [self.folderNameTextField setEnabled:YES];
    
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
    if ([textField isEqual:self.folderNameTextField]) {
        [self.folderNameTextField resignFirstResponder];
    }
    
    return YES;
}

#pragma mark - Folder Creation

- (void)createFolderWithName:(NSString *)name error:(NSError *__autoreleasing *)error
{
    // Check that no folder with the same path has the same name
    CBLQuery *pathQuery = [[[CCDBManager sharedInstance].database viewNamed:@"byPath"] createQuery];
    pathQuery.keys = @[self.path];
    [pathQuery runAsync:^(CBLQueryEnumerator *rowsEnum, NSError *error){
        for (CBLQueryRow *row in rowsEnum) {
            CBLDocument *doc = row.document;
            if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"Folder"]
                && [[doc.properties valueForKey:@"name"] isEqualToString:name]) {
                
                NSString *desc = @"Un dossier existant porte déjà ce nom";
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
                
                [[CCErrorHandler sharedInstance] populateError:&error
                        withCode:-101 userInfo:userInfo];
                return;
            }
        }
        
        // Create the folder
        NSDictionary *contents = @{@"name" : self.folderNameTextField.text,
                                   @"path" : self.path,
                                   @"docType" : @"Folder"
                                   };
        
        CBLDocument *doc = [[CCDBManager sharedInstance].database createDocument];
        [doc putProperties:contents error:&error];
    }];
}

#pragma mark - Custom

- (IBAction)createPressed:(id)sender
{
    [self.folderNameTextField setEnabled:NO];
    if (![self.folderNameTextField.text isEqualToString:@""]) {
        NSError *error;
        [self createFolderWithName:self.folderNameTextField.text error:&error];
        if (error) {
            [[CCErrorHandler sharedInstance] presentError:error
                withMessage:[ccErrorDefault copy]
                fatal:NO];
        }
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setAppearance
{
    self.folderNameTextField.layer.borderColor = [kYellow CGColor];
    self.folderNameTextField.layer.borderWidth = kBorderWidth;
    self.folderNameTextField.layer.cornerRadius = kCornerRadius;
}

@end
