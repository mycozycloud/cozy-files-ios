//
//  CCFileNavigationViewController.m
//  Cozy Files
//
//  Created by William Archimede on 29/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"
#import "CCFileViewerViewController.h"
#import "CCEditionViewController.h"
#import "CCFileNavigationViewController.h"

@interface CCFileNavigationViewController () <CBLUITableDelegate, UIAlertViewDelegate,
UIActionSheetDelegate>
- (void)goBackToRoot;
- (void)setAppearance;
@property (strong, nonatomic) CBLQueryRow *rowToDelete;
- (void)prepareForDeletion;
- (void)showDeleteAlert;
- (void)deleteRecursively:(CBLDocument *)doc error:(NSError **)error;
- (void)showActions;
@end

@implementation CCFileNavigationViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.delegate = self;
    
    if (self.path) {
        self.title = [[self.path componentsSeparatedByString:@"/"] lastObject];
    } else {
        self.title = @"Fichiers";
    }
    
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    
    // TableView and TableSource setup
    CBLView *pathView = [appDelegate.database viewNamed:@"byPath"];
    CBLLiveQuery *query = [[pathView query] asLiveQuery];
    query.keys = self.path ? @[self.path] : @[@""]; // empty path is root
    self.tableSource = [[CBLUITableSource alloc] init];
    self.tableSource.query = query;
    self.tableSource.tableView = self.tableView;
    self.tableSource.labelProperty = @"name";
    self.tableView.dataSource = self.tableSource;
    
    // Menu reveal
    [self.menuButton setTarget:self.revealViewController];
    [self.menuButton setAction:@selector(revealToggle:)];
    
    // Back to root
    [self.rootButton setTarget:self];
    [self.rootButton setAction:@selector(goBackToRoot)];
    if (!self.path) {
#warning For now, till I find a better UX idea
        self.rootButton.enabled = NO;
    }
    
    // Actions
    [self.actionButton setTarget:self];
    [self.actionButton setAction:@selector(showActions)];
    
    // Appearance
    [self setAppearance];
}

- (void)viewWillAppear:(BOOL)animated
{
}

- (void)viewDidAppear:(BOOL)animated
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    // ProgressView setup for replication monitoring
    [appDelegate.push addObserver:self
                       forKeyPath:@"completed"
                          options:0
                          context:NULL];
    [appDelegate.pull addObserver:self
                       forKeyPath:@"completed"
                          options:0
                          context:NULL];
    
    // Basic check to know if there's a need to display the connection screen
    NSString *remoteID = [[NSUserDefaults standardUserDefaults]
                          objectForKey:kRemoteIDKey];
    if (!remoteID) {
        [self performSegueWithIdentifier:@"ShowConnection" sender:nil];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    // End of replication monitoring
    [appDelegate.push removeObserver:self forKeyPath:@"completed"];
    [appDelegate.pull removeObserver:self forKeyPath:@"completed"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Prepare for file viewing transition
    if ([segue.identifier isEqualToString:@"ShowFile"]) {
        CBLDocument *doc = (CBLDocument *)sender;
        CCFileViewerViewController *cont = (CCFileViewerViewController *)[segue destinationViewController];
        cont.fileID = [doc.properties valueForKey:@"_id"];
    } else if ([segue.identifier isEqualToString:@"ShowEdition"]) {
        CBLDocument *doc = (CBLDocument *)sender;
        CCEditionViewController *edCont = (CCEditionViewController *)[segue destinationViewController];
        edCont.doc = doc;
    }
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBLDocument *doc = [[self.tableSource.query.rows rowAtIndex:indexPath.row] document];
    
    if (self.tableView.isEditing) {
        [self.tableView setEditing:NO animated:YES];
        [self.actionButton setTitle:@"Modifier"];
        [self performSegueWithIdentifier:@"ShowEdition" sender:doc];
    } else {
        if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"Folder"]) { // Folder, so navigate
            CCFileNavigationViewController *controller = [[UIStoryboard storyboardWithName:@"Main"
                                                                                    bundle:nil]
                instantiateViewControllerWithIdentifier:@"CCFileNavigationViewController"];
            controller.path = [NSString stringWithFormat:@"%@/%@",
                               [doc.properties valueForKey:@"path"],
                               [doc.properties valueForKey:@"name"]];
            
            [self.navigationController pushViewController:controller animated:YES];
            
        } if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"File"]) { // File, so view it
            [self performSegueWithIdentifier:@"ShowFile" sender:doc];
        }
    }
    
}

- (void)couchTableSource:(CBLUITableSource *)source willUseCell:(UITableViewCell *)cell forRow:(CBLQueryRow *)row
{
    CBLDocument *doc = row.value;
    if ([[doc valueForKey:@"docType"] isEqualToString:@"Folder"]) {
        [cell.imageView setImage:[UIImage imageNamed:@"folder"]];
    } else if ([[doc valueForKey:@"docType"] isEqualToString:@"File"]) {
        [cell.imageView setImage:[UIImage imageNamed:@"file"]];
    }
}

- (bool)couchTableSource:(CBLUITableSource *)source deleteRow:(CBLQueryRow *)row
{
    self.rowToDelete = row;
    
    [self prepareForDeletion];
    
    return NO; // We'll get rid of the row ourselves
}

#pragma mark - Replication monitoring

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
        }
    }
}

#pragma mark - Custom

- (void)goBackToRoot
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)setAppearance
{
    [self.menuButton setTintColor:kBlue];
    [self.rootButton setTintColor:kBlue];
    [self.actionButton setTintColor:kBlue];
}

- (void)showActions
{
    if (self.tableView.isEditing) {
        [self.tableView setEditing:NO animated:YES];
        [self.actionButton setTitle:@"Modifier"];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@""
                                                           delegate:self
                                                  cancelButtonTitle:@"Annuler"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Renommer ou supprimer", nil];
        
        [sheet showFromBarButtonItem:self.actionButton animated:YES];
    }
}

#pragma mark - Document Deletion

- (void)prepareForDeletion
{
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    
    CBLDocument *doc = self.rowToDelete.document;
    if ([[doc.properties valueForKey:@"docType"] isEqualToString:@"File"]) {
        NSLog(@"FILE DELETION : %@", [doc.properties valueForKey:@"name"]);
        // Just delete the file and its binary since it's not a folder
        NSError *error;
        NSString *binaryID = [[[doc.properties valueForKey:@"binary"]
                               valueForKey:@"file"] valueForKey:@"id"];
        CBLDocument *binary = [appDelegate.database documentWithID:binaryID];
        [binary purgeDocument:&error];
        [doc deleteDocument:&error];
        if (error) {
            [appDelegate showAlert:@"Une erreur est survenue" error:error fatal:NO];
        } else {
            [self.tableSource reloadFromQuery]; // Reload the view
        }
    } else { // It's a folder, so be careful with its children
        NSLog(@"FOLDER DELETION");
        NSString *path = [NSString stringWithFormat:@"%@/%@",
                          [doc.properties valueForKey:@"path"],
                          [doc.properties valueForKey:@"name"]];
        
        CBLQuery *query = [[appDelegate.database viewNamed:@"byPath"] query];
        query.keys = @[path];
        if (query.rows.count > 0) { // There are children
            NSLog(@"FOLDER HAS %i CHILDREN", query.rows.count);
            [self showDeleteAlert];
        } else { // Empty folder, so delete it
            NSLog(@"FOLDER IS EMPTY ");
            NSError *error;
            [doc deleteDocument:&error];
            if (error) {
                [appDelegate showAlert:@"Une erreur est survenue" error:error fatal:NO];
            } else {
                [self.tableSource reloadFromQuery]; // Reload the view
            }
        }
    }
}

- (void)deleteRecursively:(CBLDocument *)doc error:(NSError **)error
{
    NSLog(@"DELETE RECURSIVELY : %@", [doc.properties valueForKey:@"name"]);
    CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                   delegate];
    CBLQuery *query = [[appDelegate.database viewNamed:@"byPath"] query];
    NSString *path = [NSString stringWithFormat:@"%@/%@",
                      [doc.properties valueForKey:@"path"],
                      [doc.properties valueForKey:@"name"]];
    query.keys = @[path];
    
    for (CBLQueryRow *row in query.rows) {
        CBLDocument *child = row.document;
        
        if ([[child.properties valueForKey:@"docType"] isEqualToString:@"File"]) {
            NSLog(@"DELETE FILE : %@", [child.properties valueForKey:@"name"]);
            // Just delete the file and its binary since it's not a folder
            NSString *binaryID = [[[doc.properties valueForKey:@"binary"]
                                   valueForKey:@"file"] valueForKey:@"id"];
            CBLDocument *binary = [appDelegate.database documentWithID:binaryID];
            [binary purgeDocument:error];
            [child deleteDocument:error];
        } else { // It's a folder, so be careful with its children
            [self deleteRecursively:child error:error];
        }
    }
    
    // Now it's supposed to be empty, so delete it
    [doc deleteDocument:error];
}

- (void)showDeleteAlert
{
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Attention"
                              message:@"Ce dossier n'est pas vide. Êtes-vous sûr ?"
                              delegate:self
                              cancelButtonTitle:@"Annuler"
                              otherButtonTitles:@"Oui", nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex > 0) {
        NSError *error;
        CBLDocument *doc = self.rowToDelete.document;
        [self deleteRecursively:doc error:&error];
        
        if (error) {
            CCAppDelegate *appDelegate = (CCAppDelegate *)[[UIApplication sharedApplication]
                                                           delegate];
            [appDelegate showAlert:@"Une erreur est survenue"
                             error:error fatal:NO];
        }
    }
    
    [self.tableSource reloadFromQuery];
}

#pragma mark - Action Sheet

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [self.tableView setEditing:YES animated:YES];
        [self.actionButton setTitle:@"Ok"];
    } else {
        [self.tableView setEditing:NO animated:YES];
        [self.actionButton setTitle:@"Modifier"];
    }
}

@end
