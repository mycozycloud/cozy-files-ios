//
//  CCConfigurationViewController.m
//  Cozy Files
//
//  Created by William Archimede on 06/11/13.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import "CCConfigurationViewController.h"

@interface CCConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *menuButton;

@end

@implementation CCConfigurationViewController

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
    
    // Menu reveal
    [self.menuButton setTarget: self.revealViewController];
    [self.menuButton setAction: @selector(revealToggle:)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
