//
//  CCErrorHandler.m
//  Cozy Files
//
//  Created by William Archimede on 25/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

#import "CCErrorHandler.h"

static NSString *ccErrorDomain = @"cc.cozycloud.errordomain";

@implementation CCErrorHandler

/*
 * Singleton
 */
+ (CCErrorHandler *)sharedInstance
{
    // Static variable to hold the instance of the singleton
    static CCErrorHandler *_sharedInstance = nil;
    
    // Static variable which ensures that the initialization code
    // executes only once
    static dispatch_once_t oncePredicate;
    
    // Use GCD to execute only once the block which initializes the instance
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [CCErrorHandler new];
    });
    
    return _sharedInstance;
}

#pragma mark - UIAlertView Delegate

// Displays an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)presentError:(NSError *)error withMessage:(NSString *)message
               fatal:(BOOL)fatal
{
    if (error) {
        NSLog(@"ERROR - %@", error);
        message = [NSString stringWithFormat:@"%@\n\n%@", message,
                   error.localizedDescription];
    }
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:(fatal ? @"Erreur Fatale" : @"Erreur")
                              message:message
                              delegate:(fatal ? self : nil)
                              cancelButtonTitle:(fatal ? @"Quitter" : @"Désolé")
                              otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // If it's a fatal error, the app closes
    exit(0);
}

#pragma mark - Custom

- (void)populateError:(NSError *__autoreleasing*)error withCode:(NSInteger)code
             userInfo:(NSDictionary *)dict
{
    *error = [NSError errorWithDomain:ccErrorDomain code:code userInfo:dict];
}

@end
