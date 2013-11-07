//
//  CCFileNavigationViewController.m
//  Cozy Files
//
//  Created by William Archimede on 29/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CCAppDelegate.h"
#import "CCFileNavigationViewController.h"

@interface CCFileNavigationViewController () <CBLUITableDelegate>
- (void)goBackToRoot;
- (void)setAppearance;
@end

@implementation CCFileNavigationViewController

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
    
    // ProgressView setup for replication monitoring
    [appDelegate.push addObserver:self
                       forKeyPath:@"completed"
                          options:0
                          context:NULL];
    [appDelegate.pull addObserver:self
                       forKeyPath:@"completed"
                          options:0
                          context:NULL];
    
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
    
    // Appearance
    [self setAppearance];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSString *remoteID = [[NSUserDefaults standardUserDefaults]
                          objectForKey:kRemoteIDKey];
    if (!remoteID) {
        [self performSegueWithIdentifier:@"ShowConnection" sender:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - TableView Delegate
- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBLDocument *doc = [[self.tableSource.query.rows rowAtIndex:indexPath.row] value];
    if ([[doc valueForKey:@"docType"] isEqualToString:@"Folder"]) {
        CCFileNavigationViewController *controller = [[UIStoryboard storyboardWithName:@"Main"
                                                                bundle:nil]
                        instantiateViewControllerWithIdentifier:@"CCFileNavigationViewController"];
        controller.path = [NSString stringWithFormat:@"%@/%@",
                           [doc valueForKey:@"path"],
                           [doc valueForKey:@"name"]];
        
        [self.navigationController pushViewController:controller animated:YES];
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
}

@end
