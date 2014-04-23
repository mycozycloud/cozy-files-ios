//
//  CCConstants.h
//  Cozy Files
//
//  Created by William Archimede on 25/03/2014.
//  Copyright (c) 2014 CozyCloud. All rights reserved.
//

#ifndef Cozy_Files_CCConstants_h
#define Cozy_Files_CCConstants_h

// Appearance constants
#define kYellow [UIColor colorWithRed:254/255.0 green:136/255.0 blue:0 alpha:1]
#define kBlue [UIColor colorWithRed:0.24 green:0.73 blue:0.89 alpha:1]
#define kBorderWidth 0.8
#define kCornerRadius 5.0

// Preferences constants
static const NSString *ccRemoteIDKey = @"cozyFilesRemoteID";
static const NSString *ccRemoteLoginKey = @"cozyFilesRemoteLogin";
static const NSString *ccCozyURLKey = @"cozyURL";
static const NSString *ccLastImportDateKey = @"lastImportDate";
static const NSString *ccPhotosWaitingForImport = @"photosWaitingForImport";
static const NSString *ccBinaryWaitingForPush = @"binaryWaitingForPush";

#endif
