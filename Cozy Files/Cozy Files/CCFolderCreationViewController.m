//
//  CCFolderCreationViewController.m
//  Cozy Files
//
//  Created by William Archimede on 21/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"
#import "CCFolderCreationViewController.h"

@interface CCFolderCreationViewController ()
- (void)setAppearance;
- (void)createFolderWithName:(NSString *)name error:(NSError **)error;
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
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    
    // Check that no folder with the same path has the same name
    CBLQuery *pathQuery = [[appDelegate.database viewNamed:@"byPath"] createQuery];
    pathQuery.keys = @[self.path];
    [pathQuery runAsync:^(CBLQueryEnumerator *rowsEnum, NSError *error){
        for (CBLQueryRow *row in rowsEnum) {
            CBLDocument *doc = row.document;
            if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"Folder"]
                && [[doc.properties valueForKey:@"name"] isEqualToString:name]) {
                
                NSString *desc = @"Un dossier existant porte déjà ce nom";
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
                
                error = [NSError errorWithDomain:kErrorDomain code:-101 userInfo:userInfo];
                return;
            }
        }
        
        // Create the folder
        NSDictionary *contents = @{@"name" : self.folderNameTextField.text,
                                   @"path" : self.path,
                                   @"docType" : @"Folder"
                                   };
        
        CBLDocument *doc = [appDelegate.database createDocument];
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
            CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                           delegate];
            [appDelegate showAlert:@"Une erreur est survenue"
                             error:error fatal:NO];
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
