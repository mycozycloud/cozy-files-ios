//
//  CCFileViewerViewController.h
//  Cozy Files
//
//  Created by William Archimede on 08/11/2013.
//  Copyright (c) 2013 CozyCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCFileViewerViewController : UIViewController
@property (strong, nonatomic) NSString *fileID;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (weak, nonatomic) IBOutlet UITextView *txtView;
@end
