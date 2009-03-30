//
//  Constants.h
//  WordPress
//
//  Created by Ganesh Ramachandran on 6/6/08.
//

// Blog archive file name
#define BLOG_ARCHIVE_NAME				WordPress_Blogs

// control dimensions
#define kStdButtonWidth			106.0
#define kStdButtonHeight		40.0

#define kTextFieldHeight		20.0
#define kTextFieldFontSize		18.0
#define kTextFieldFont			@"Arial"

#define kLabelHeight			20.0
#define kLabelWidth				90.0
#define kLabelFont			@"Arial"

#define kProgressIndicatorSize	40.0
#define kToolbarHeight			40.0
#define kSegmentedControlHeight 40.0

// table view cell 
#define kCellLeftOffset			4.0
#define kCellTopOffset			12.0
#define kCellRightOffset		32.0
#define kCellFieldSpacer		14.0
#define kCellWidth				300.0
#define kCellHeight				44.0


#ifdef DEBUGMODE
#define WPLog NSLog
#else
#define WPLog //NSLog
#endif

#define kResizePhotoSetting @"ResizePhotoSetting"
#define kAsyncPostFlag @"async_post"
#define kSupportsPagesAndComments @"SupportsPagesAndComments"
#define kVersionAlertShown @"VersionAlertShown"
#define kSupportsPagesAndCommentsServerCheck @"SupportsPagesAndCommentsServerCheck"
#define kResizePhotoSettingHintLabel @"Resizing will result in faster publishing \n but smaller photos. Resized photos \n will be no larger than 640 x 480."
#define kPasswordHintLabel @"Setting a password will require visitors to \n enter the above password to view this \n post and its comments."