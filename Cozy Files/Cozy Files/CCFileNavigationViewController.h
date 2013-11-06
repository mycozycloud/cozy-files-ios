//
//  CCFileNavigationViewController.h
//  Cozy Files
//
//  Created by William Archimede on 29/10/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SWRevealViewController.h"

@class CBLUITableSource;

@interface CCFileNavigationViewController : UIViewController
<UITableViewDelegate>

@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) CBLUITableSource *tableSource;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *menuButton;

@end
