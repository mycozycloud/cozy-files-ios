//
//  CCEditionViewController.m
//  Cozy Files
//
//  Created by William Archimede on 18/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"
#import "CCErrorHandler.h"
#import "CCEditionViewController.h"

@interface CCEditionViewController ()
- (void)setAppearance;
- (void)renameRecursively:(CBLDocument *)doc newPath:(NSString *)newPath
                    error:(NSError **)error;
@end

@implementation CCEditionViewController

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
    self.docNameTextField.delegate = self;
    self.docNameTextField.text = [self.doc.properties valueForKey:@"name"];
    [self.docNameTextField setEnabled:YES];
    
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
    if ([textField isEqual:self.docNameTextField]) {
        [self.docNameTextField resignFirstResponder];
    }
    
    return YES;
}

#pragma mark - Document Renaming

- (void)renameRecursively:(CBLDocument *)doc newPath:(NSString *)newPath
                    error:(NSError *__autoreleasing *)error
{
    NSLog(@"RENAME RECURSIVELY : %@", [doc.properties valueForKey:@"name"]);
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    // Query the current outdated path for navigation in the tree
    CBLQuery *query = [[appDelegate.database viewNamed:@"byPath"] createQuery];
    NSString *queryPath = [NSString stringWithFormat:@"%@/%@",
                      [doc.properties valueForKey:@"path"],
                      [doc.properties valueForKey:@"name"]];
    query.keys = @[queryPath];
    
    // Build the new path
    NSString *newNewPath;
    if ([doc isEqual:self.doc]) {
        newNewPath = [NSString stringWithFormat:@"%@/%@",
                    newPath, self.docNameTextField.text];
    } else {
        newNewPath = [NSString stringWithFormat:@"%@/%@",
           newPath, [doc.properties valueForKey:@"name"]];
    }
    
//    CBLQueryEnumerator *rowsEnum = [query rows:error];
    [query runAsync:^(CBLQueryEnumerator *rowsEnum, NSError *error){
        for (CBLQueryRow *row in rowsEnum) {
            CBLDocument *child = row.document;
            
            if ([[child.properties valueForKey:@"docType"] isEqualToString:@"File"]) {
                NSLog(@"EDIT PATH FILE : %@", [child.properties valueForKey:@"name"]);
                // Just edit the path of the file since it's not a folder
                // Copy the document
                NSMutableDictionary *contents = [child.properties mutableCopy];
                // Change its path
                [contents setObject:newNewPath forKey: @"path"];
                // Save the updated document
                [child putProperties:contents error:&error];
                
            } else { // It's a folder, so be careful with its children
                [self renameRecursively:child newPath:newNewPath error:&error];
            }
        }
        
        // Now its children are supposed to be edited, so edit it
        // Copy the document
        NSMutableDictionary *contents = [doc.properties mutableCopy];
        if ([doc isEqual:self.doc]) { // Rename the document
            // Change its name
            [contents setObject:self.docNameTextField.text forKey: @"name"];
        } else if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"Folder"]) {
            // Edit the path of the folder
            // Change its path
            [contents setObject:newPath forKey: @"path"];
        }
        // Save the updated document
        [doc putProperties:contents error:&error];
    }];
}

#pragma mark - Custom

- (IBAction)renamePressed:(id)sender
{
    [self.docNameTextField setEnabled:NO];
    // If the name doesn't change, there is nothing to do
    if (![self.docNameTextField.text isEqualToString:[self.doc.properties valueForKey:@"name"]]) {
        CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                       delegate];
        
        // Check that no element with the same path and docType has the same name
        CBLQuery *pathQuery = [[appDelegate.database viewNamed:@"byPath"] createQuery];
        pathQuery.keys = @[[self.doc.properties valueForKey:@"path"]];
        [pathQuery runAsync:^(CBLQueryEnumerator *rowsEnum, NSError *error){
            for (CBLQueryRow *row in rowsEnum) {
                CBLDocument *document = row.document;
                if ([[document.properties valueForKey:@"docType"]
                     isEqualToString:[self.doc.properties valueForKey:@"docType"]]
                    && [[document.properties valueForKey:@"name"]
                        isEqualToString:self.docNameTextField.text]) {
                        
                        NSString *desc = @"Un dossier existant porte déjà ce nom";
                        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desc};
                        
                        [[CCErrorHandler sharedInstance] populateError:&error
                            withCode:-101
                            userInfo:userInfo];
                    }
            }
            
            if (error) { // There's already an element here with same docType and name
                [[CCErrorHandler sharedInstance] presentError:error
                    withMessage:[ccErrorDefault copy]
                    fatal:NO];
            } else { // The doc can be renamed
                [self renameRecursively:self.doc
                                newPath:[self.doc.properties valueForKey:@"path"]
                                  error:&error];
                if (error) {
                    [[CCErrorHandler sharedInstance] presentError:error
                        withMessage:[ccErrorDefault copy]
                        fatal:NO];
                }
            }
        }];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setAppearance
{
    self.docNameTextField.layer.borderColor = [kYellow CGColor];
    self.docNameTextField.layer.borderWidth = kBorderWidth;
    self.docNameTextField.layer.cornerRadius = kCornerRadius;
}

@end
