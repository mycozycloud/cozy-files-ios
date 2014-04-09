//
//  CCErrorHandler.h
//  Cozy Files
//
//  Created by William Archimede on 25/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

@import Foundation;

// Error messages
static const NSString *ccErrorDefault =  @"Une erreur s'est produite";
static const NSString *ccErrorDBAccess =  @"L'app n'a pas pu accéder à la base de données";
static const NSString *ccErrorPhotoAccess =  @"Vous devez autoriser l'app à accéder à vos photos dans les paramètres de confidentialité de votre iPhone";
static const NSString *ccErrorPhotoImport =  @"Une erreur s'est produite pendant l'import des photos";

@interface CCErrorHandler : NSObject <UIAlertViewDelegate>

/*! Retrieves or creates the singleton instance of CCErrorHandler.
 * \returns the shared instance of the error handler.
 */
+ (CCErrorHandler *)sharedInstance;

/*!
 * Creates an alert view and displays it to the user.
 * \param error The error to present
 * \param message A user friendly message accompanying the error
 * \param fatal A boolean indicating when an error is fatal and will force an exit
 */
- (void)presentError:(NSError *)error withMessage:(NSString *)message
               fatal:(BOOL)fatal;

/*! Populates an error.
 * \param error The error object to fill
 * \param code The code of the error
 * \param dict The dictionary containing user info
 */
- (void)populateError:(NSError *__autoreleasing*)error withCode:(NSInteger)code
             userInfo:(NSDictionary *)dict;
@end
