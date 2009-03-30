#import <UIKit/UIKit.h>
#import "Constants.h"

#ifdef BROMINE_ENABLED
#import "HTTPServer.h"
#endif

@interface WordPressAppDelegate : NSObject <UIApplicationDelegate> {
	
	IBOutlet UIWindow *window;
	IBOutlet UINavigationController *navigationController;
	BOOL alertRunning;

#ifdef BROMINE_ENABLED
	HTTPServer *httpServer;
#endif
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UINavigationController *navigationController;
@property (nonatomic, getter=isAlertRunning) BOOL alertRunning;

+ (WordPressAppDelegate *)sharedWordPressApp;

@end

