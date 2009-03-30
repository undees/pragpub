#import "BlogDataManager.h"
#import "WordPressAppDelegate.h"
#import "CoreGraphics/CoreGraphics.h"
#import "WPXMLReader.h"

#define kURL @"URL"
#define kMETHOD @"METHOD"
#define kMETHODARGS @"METHODARGS"

#define pictureData @"pictureData"
#define pictureStatus @"pictureStatus"
#define pictureCaption @"pictureCaption"
#define pictureInfo @"pictureInfo"
#define pictureSize @"pictureSize"
#define pictureFileSize @"pictureFileSize"
#define pictureURL @"pictureURL"

#define kNextDraftIdStr @"kNextDraftIdStr"
#define kNextPageDraftIdStr @"kNextPageDraftIdStr"
#define kDraftsCount @"kDraftsCount"
#define kPageDraftsCount @"kPageDraftsCount"
#define kNumberOfCommentsToDisplay 100

@interface BlogDataManager (private)

- (void) loadBlogData;
- (void) setBlogsList:(NSMutableArray *)newArray;
- (void) createDemoBlogData;
- (void) sortBlogData;

- (NSString *)pathToPostTitles:(id)forBlog;
- (NSString *)pathToPost:(id)aPost forBlog:(id)aBlog;
- (NSString *)postFileName:(id)aPost;
- (NSString *)templatePathForBlog:(id)aBlog;
- (NSString *)commentsFolderPathForBlog:(id)aBlog;
- (NSString *)commentFilePath:(id)aComment forBlog:(id)aBlog;

- (void) loadPhotosDB;
- (void) createPhotosDB;
- (void) loadPostTitlesForCurrentBlog;
- (void)loadPageTitlesForCurrentBlog;
- (id)loadPageTitlesForBlog:(id)aBlog;
- (void) setPostTitlesList:(NSMutableArray *)newArray;
- (void) setCommentTitlesList:(NSMutableArray *)newArray;
- (NSInteger) indexOfPostTitle:(id)postTitle inList:(NSArray *)aPostTitlesList;

// set methods will release current and create mutable copy
- (void) setCurrentBlog:(NSMutableDictionary *)aBlog;
- (void) setCurrentPost:(NSMutableDictionary *)aPost;

- (NSMutableDictionary *) postTitleForPost:(NSDictionary *)aPost;
- (NSMutableDictionary *) commentTitleForComment:(NSDictionary *)aComment ;


- (void) sortPostsList;
//- (void) sortPostsListByAuthorAndDate;
- (void)setDraftTitlesList:(NSMutableArray *)newArray;
- (void)setPageDraftTitlesList:(NSMutableArray *)newArray;


//argument should provide all required perameters for 
- (void)addAsyncOperation:(SEL)anOperation withArg:(id)anArg;

- (BOOL)deleteAllPhotosForPost:(id)aPost forBlog:(id)aBlog;
- (BOOL)deleteAllPhotosForCurrentPostBlog;


//pages

- (NSString *)pathToPageTitles:(id)aBlog;
- (void) setPageTitlesList:(NSMutableArray *)newArray;
- (NSString *)pageFilePath:(id)aPage forBlog:(id)aBlog;
- (id)fectchNewPage:(NSString *)pageid formBlog:(id)aBlog;
- (NSMutableDictionary *) pageTitleForPage:(NSDictionary *)aPage;
- (BOOL)deleteAllPhotosForPage:(id)aPage forBlog:(id)aBlog;
@end

@implementation BlogDataManager

static BlogDataManager *sharedDataManager;

@synthesize blogFieldNames, blogFieldNamesByTag, blogFieldTagsByName, 
pictureFieldNames, postFieldNames, postFieldNamesByTag, postFieldTagsByName,
postTitleFieldNames, postTitleFieldNamesByTag, postTitleFieldTagsByName,unsavedPostsCount,currentPageIndex,currentPage,pageFieldNames,
currentBlog, currentPost, currentDirectoryPath, photosDB, currentPicture, isLocaDraftsCurrent, isPageLocalDraftsCurrent, currentPostIndex, currentDraftIndex,currentPageDraftIndex,asyncPostsOperationsQueue,currentUnsavedDraft;


- (void)dealloc {
	
	[blogsList release];
	[currentBlog release];
	[postTitlesList release];
	[pageTitlesList release];
	[currentPost release];
	[currentPage release];
	[currentDirectoryPath release];
	
	[photosDB release];
	[currentPicture release];
	
	[blogFieldNames release];
	[blogFieldNamesByTag release];
	[blogFieldTagsByName release];
	
	[pictureFieldNames release];
	
	[postTitleFieldNames release];
	[postTitleFieldNamesByTag release];
	[postTitleFieldTagsByName release];
	
	[postFieldNames release];
	[pageFieldNames release];
	[postFieldNamesByTag release];
	[postFieldTagsByName release];
	
	[asyncOperationsQueue release];
	[asyncPostsOperationsQueue release];
	[currentUnsavedDraft release];
	[super dealloc];
}


// Initialize the singleton instance if needed and return
+(BlogDataManager *)sharedDataManager
{
//	@synchronized(self)
	{
		if (!sharedDataManager)
			sharedDataManager = [[BlogDataManager alloc] init];
		
		return sharedDataManager;
	}
}

+(id)alloc
{
//	@synchronized(self)
	{
		NSAssert(sharedDataManager == nil, @"Attempted to allocate a second instance of a singleton.");
		sharedDataManager = [super alloc];
		return sharedDataManager;
	}
}

+(id)copy
{
//	@synchronized(self)
	{
		NSAssert(sharedDataManager == nil, @"Attempted to copy the singleton.");
		return sharedDataManager;
	}
}

+ (void)initialize
{
    static BOOL initialized = NO;
    if (!initialized) {
		// Load any previously archived blog data
		[[BlogDataManager sharedDataManager] loadBlogData];

        initialized = YES;
    }
}

- (id)init
{
	if( self = [super init] )
	{
		asyncOperationsQueue = [[NSOperationQueue alloc] init];
		[asyncOperationsQueue setMaxConcurrentOperationCount:2];
		asyncPostsOperationsQueue=[[NSOperationQueue alloc] init];
		[asyncPostsOperationsQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
		
		// Set current directory for Wordpress app
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		self.currentDirectoryPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"wordpress"];
		
		BOOL isDir;
		if (![fileManager fileExistsAtPath:self.currentDirectoryPath isDirectory:&isDir] || !isDir) {
			[fileManager createDirectoryAtPath:self.currentDirectoryPath attributes:nil];
		}
		// set the current dir
		[fileManager changeCurrentDirectoryPath:self.currentDirectoryPath];
		
		// allocate lists
//		self->blogsList = [[NSMutableArray alloc] initWithCapacity:10];
//		self->postTitlesList = [[NSMutableArray alloc] initWithCapacity:50];
//		self->draftTitlesList = [[NSMutableArray alloc] initWithCapacity:50];
//		
	}
	return self;
}



#pragma mark - XMLRPC

- (NSError *)defaultError
{
	NSDictionary *usrInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Failed to request the server.", NSLocalizedDescriptionKey, nil];
	return [NSError errorWithDomain:@"com.effigent.iphone.wordpress" code:-1 userInfo:usrInfo];
}

- (BOOL)handleError:(NSError *)err
{
	UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:@"Communication Error"
													 message:[err localizedDescription]
													delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	
	[alert1 show];
	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	[delegate setAlertRunning:YES];

	
	[alert1 release];
	return YES;
}

- (NSError *)errorWithResponse:(XMLRPCResponse *)res shouldHandle:(BOOL)shouldHandleFlag
{
	NSError *err = nil;
	if( !res )
		err = [self defaultError];

	if ( [res isKindOfClass:[NSError class]] )
		err = (NSError *)res;
	else
	{
		if ( [res isFault] )
		{
			NSDictionary *usrInfo = [NSDictionary dictionaryWithObjectsAndKeys:[res fault], NSLocalizedDescriptionKey, nil];
			err = [NSError errorWithDomain:@"com.effigent.iphone.wordpress" code:[[res code] intValue] userInfo:usrInfo];
		}
		
		if ( [res isParseError] )
		{
			err = [res object];
		}		
	}
	
	if( err && shouldHandleFlag )
	{
		// patch to eat the zero posts error
		// "Either there are no posts, or something went wrong."
		
		NSString *zeroPostsError = @"Either there are no posts, or something went wrong.";
		NSRange range = [[err description] rangeOfString:zeroPostsError options:NSBackwardsSearch];
		if (range.location == NSNotFound) {
			[self handleError:err]; 
		} else {
			return [NSMutableArray array];
		}
	}
	
	return err;
}

- (id)executeXMLRPCRequest:(XMLRPCRequest *)req byHandlingError:(BOOL)shouldHandleFalg
{
	XMLRPCResponse *userInfoResponse = [XMLRPCConnection sendSynchronousXMLRPCRequest:req];
	NSError *err = [self errorWithResponse:userInfoResponse shouldHandle:shouldHandleFalg];

	if( err )
		return err;
	
	return [userInfoResponse object];
}

#pragma mark -
#pragma mark async

//

- (void)addAsyncOperation:(SEL)anOperation withArg:(id)anArg
{	
    if( ![self respondsToSelector:anOperation] )
	{
		return;
	}
	
	NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:anOperation object:anArg];
	[asyncOperationsQueue addOperation:op];
	[op release];
}

#pragma mark -

//syncronous method
//you can access the current context.
- (void)addSendPictureMsgToQueue:(id)aPicture
{	
	//create args
	NSData *pictData = UIImagePNGRepresentation([aPicture valueForKey:@"pictureData"]);
	if( pictData == nil )
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Invalid Image. Unable to Upload to the server." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		[alert release];
		return;
	}
	
	//test code
	if( ![self countOfBlogs] )
	{
		return;
	}
	
//	[self makeBlogAtIndexCurrent:[self countOfBlogs]-1];

	if( !currentBlog )
	{
		return;
	}
	
//	NSString *name = [[[aPicture valueForKey:@"pictureFilePath"] stringByDeletingPathExtension] lastPathComponent];
//	name = ( name == nil ? @"", name );

	NSString *desc = [aPicture valueForKey:@"pictureCaption"];
	desc = ( desc == nil ? @"" : desc );
	
	NSString *name = [aPicture valueForKey:@"pictureCaption"];
	name = ( name == nil ? @"iphoneImage.png" : [name stringByAppendingFormat:@".png"] );

	NSString *categories = nil;//[aPicture valueForKey:@"pictureCaption"];
	categories = ( categories == nil ? [NSArray array] : categories );

	NSMutableDictionary *imageParms = [NSMutableDictionary dictionary];
	[imageParms setValue:@"image/png" forKey:@"type"];
	[imageParms setValue:pictData forKey:@"bits"];
	[imageParms setValue:name forKey:@"name"];
	[imageParms setValue:categories forKey:@"categories"];
	[imageParms setValue:desc forKey:@"description"];
	
	NSArray *args = [NSArray arrayWithObjects:[currentBlog valueForKey:@"blogid"],
					 [currentBlog valueForKey:@"username"],
					 [currentBlog valueForKey:@"pwd"],
					 imageParms,
					 nil
					 ];
	
	NSMutableDictionary *params = [NSMutableDictionary dictionary];
	[params setObject:[currentBlog valueForKey:@"xmlrpc"] forKey:kURL];
	[params setObject:@"metaWeblog.newMediaObject" forKey:kMETHOD];
	[params setObject:args forKey:kMETHODARGS];

	//method specific values
	[params setObject:aPicture forKey:@"pictureObj"];
	[aPicture setValue:[NSNumber numberWithInt:1] forKey:pictureStatus];

	[self addAsyncOperation:@selector(sendPictureAsyncronously:) withArg:params];
}

//asyncronous method
//you have to get every thing with the arg prepared by the syncronous method
- (void)sendPictureAsyncronously:(id)aPictureInfo
{
	//create an xmlrpc request
	//perform the operation
	//if success then update the picture object.
//	[[aPictureInfo valueForKey:@"pictureObj"] setValue:[NSNumber numberWithInt:1] forKey:pictureStatus];

	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aPictureInfo valueForKey:kURL]]];
	[request setMethod:[aPictureInfo valueForKey:kMETHOD] withObjects:[aPictureInfo valueForKey:kMETHODARGS]];
	
	id response = [self executeXMLRPCRequest:request byHandlingError:YES];
	id pictObj = [aPictureInfo valueForKey:@"pictureObj"];
	[request release];
//	XMLRPCResponse *response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
	if( [response isKindOfClass:[NSError class]] )
	{
		[pictObj setValue:[response fault] forKey:@"faultString"];
		[pictObj setValue:[NSNumber numberWithInt:-1] forKey:pictureStatus];
	}
	else
	{
		[pictObj setValue:[NSNumber numberWithInt:2] forKey:pictureStatus];
		[pictObj removeObjectForKey:@"faultString"];
		[pictObj setValue:[response valueForKey:@"url"] forKey:pictureURL];
//		[pictObj setValue:[response valueForKey:@"file"] forKey:pictureURL];
//		[pictObj setValue:[response valueForKey:@"type"] forKey:pictureURL];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PictureObjectUploadedNotificationName object:pictObj];
	return;
}

- (void)addSyncPostsForBlogToQueue:(id)aBlog
{
	[aBlog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	//TODO: Raise a notification so that post titles will reload data. if this blog is currently viewed.
	[self addAsyncOperation:@selector(syncPostsForBlog:) withArg:aBlog];
}

- (void)syncPostsForAllBlogsToQueue:(id)sender
{
	int i, countOfBlogs = [self countOfBlogs];
	for( i=1; i < countOfBlogs; i++ )
	{
		[self addSyncPostsForBlogToQueue:[blogsList objectAtIndex:i]];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:nil userInfo:nil];
}

#pragma mark -
#pragma mark Picture metadata

- (NSArray *)pictureFieldNames {	
	if (!pictureFieldNames) {
		self->pictureFieldNames = [NSArray arrayWithObjects:@"pictureFilePath", @"pictureStatus", @"pictureCaption",@"pictureInfo",@"pictureName",nil];
		[pictureFieldNames retain];
	}
	return pictureFieldNames;
}

- (NSString *)pictureURLBySendingToServer:(UIImage *)pict
{
	NSData *pictData = UIImagePNGRepresentation(pict);
	if( pictData == nil )
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Invalid Image. Unable to Upload to the server." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		return nil;
	}
	
	NSMutableDictionary *imageParms = [NSMutableDictionary dictionary];
	[imageParms setValue:@"image/png" forKey:@"type"];
	[imageParms setValue:pictData forKey:@"bits"];
	[imageParms setValue:@"iPhoneImage.png" forKey:@"name"];
	//	[imageParms setValue:categories forKey:@"categories"];
	//	[imageParms setValue:desc forKey:@"description"];
	
	id blog = [self blogForId:[currentPost valueForKey:@"blogid"] hostName:[currentPost valueForKey:@"blog_host_name"]];

	NSArray *args = [NSArray arrayWithObjects:[blog valueForKey:@"blogid"],
					 [blog valueForKey:@"username"],
					 [blog valueForKey:@"pwd"],
					 imageParms,
					 nil
					 ];
	
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[blog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"metaWeblog.newMediaObject" withObjects:args];
	
	id response = [self executeXMLRPCRequest:request byHandlingError:YES];
	[request release];
	
	if( [response isKindOfClass:[NSError class]] )
	{
		return nil;
	}
	else
	{
		return [response valueForKey:@"url"];
	}
	
	return nil;
}

- (NSString *)pictureURLForPicturePathBySendingToServer:(NSString *)filePath
{
//	UIImage *pict = [UIImage imageWithContentsOfFile:filePath];
		//UIImagePNGRepresentation(pict);s
	NSData *pictData = [NSData dataWithContentsOfFile:filePath];
	if( pictData == nil )
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Invalid Image. Unable to Upload to the server." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		return nil;
	}

	NSMutableDictionary *imageParms = [NSMutableDictionary dictionary];
	[imageParms setValue:@"image/jpeg" forKey:@"type"];
	[imageParms setValue:pictData forKey:@"bits"];
	[imageParms setValue:[filePath lastPathComponent] forKey:@"name"];
	//	[imageParms setValue:categories forKey:@"categories"];
	//	[imageParms setValue:desc forKey:@"description"];
	
	id blog = [self blogForId:[currentPost valueForKey:@"blogid"] hostName:[currentPost valueForKey:@"blog_host_name"]];
	
	NSArray *args = [NSArray arrayWithObjects:[blog valueForKey:@"blogid"],
					 [blog valueForKey:@"username"],
					 [blog valueForKey:@"pwd"],
					 imageParms,
					 nil
					 ];
	
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[blog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"metaWeblog.newMediaObject" withObjects:args];
	
	id response = [self executeXMLRPCRequest:request byHandlingError:YES];
	[request release];
	if( [response isKindOfClass:[NSError class]] )
	{
		return nil;
	}
	else
	{
		return [response valueForKey:@"url"];
	}
	
	return nil;
}

- (NSString *)pagePictureURLForPicturePathBySendingToServer:(NSString *)filePath
{
	//	UIImage *pict = [UIImage imageWithContentsOfFile:filePath];
	//UIImagePNGRepresentation(pict);s
	NSData *pictData = [NSData dataWithContentsOfFile:filePath];
	if( pictData == nil )
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Invalid Image. Unable to Upload to the server." 
													   delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		return nil;
	}
	
	NSMutableDictionary *imageParms = [NSMutableDictionary dictionary];
	[imageParms setValue:@"image/jpeg" forKey:@"type"];
	[imageParms setValue:pictData forKey:@"bits"];
	[imageParms setValue:[filePath lastPathComponent] forKey:@"name"];
	//	[imageParms setValue:categories forKey:@"categories"];
	//	[imageParms setValue:desc forKey:@"description"];
	
	//id blog = [self blogForId:[currentPost valueForKey:@"blogid"] hostName:[currentPost valueForKey:@"blog_host_name"]];
	id blog = [self blogForId:[currentPage valueForKey:@"blogid"] hostName:[currentPage valueForKey:@"blog_host_name"]];
	
	
	
	NSArray *args = [NSArray arrayWithObjects:[blog valueForKey:@"blogid"],
					 [blog valueForKey:@"username"],
					 [blog valueForKey:@"pwd"],
					 imageParms,
					 nil
					 ];
	
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[blog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"metaWeblog.newMediaObject" withObjects:args];
	
	id response = [self executeXMLRPCRequest:request byHandlingError:YES];
	[request release];
	if( [response isKindOfClass:[NSError class]] )
	{
		return nil;
	}
	else
	{
		return [response valueForKey:@"url"];
	}
	
	return nil;
}

- (BOOL)postDescriptionHasValidDescription:(id)aPost
{
//	return [[WPXMLValidator sharedValidator] isValidXMLString:[aPost valueForKey:@"description"]];
	return YES;
}

- (NSString *)imageTagForPath:(NSString *)path andURL:(NSString *)urlStr
{
	NSArray *comps = [path componentsSeparatedByString:@"_"];

	float width, height;
	if( [path hasPrefix:@"l"] )
	{
		width = [[comps objectAtIndex:1] floatValue];
		height = [[comps objectAtIndex:2] floatValue];
	}
	else {
		width = [[comps objectAtIndex:2] floatValue];
		height = [[comps objectAtIndex:1] floatValue];
	}

	float kMaxResolution = 300.0f; // Or whatever
	if (width > kMaxResolution || height > kMaxResolution) {
		float ratio = width/height;

		if (ratio > 1.0) {
			width = kMaxResolution;
			height = (width / ratio);
		}
		else {

			height = kMaxResolution;
			width = (height * ratio);
		}
	}
	
	return [NSString stringWithFormat:@"<img src=\"%@\" alt=\"\" width=\"%d\" height=\"%d\" class=\"alignnone size-full wp-image-364\" />", urlStr, (int)width, (int)height ];
}
- (BOOL)appendImagesToPostDescription:(id)aPost
{
	NSMutableArray *photos = [aPost valueForKey:@"Photos"];
	int i, count = [photos count];
	NSString *curPath = nil;
	
	NSString *desc = [aPost valueForKey:@"description"];
	BOOL firstImage = YES;
	BOOL paraOpen = NO;
	
	for( i=count-1; i >=0 ; i-- )
	{
		curPath = [photos objectAtIndex:i];
		NSString *filePAth = [NSString stringWithFormat:@"%@/%@",[self blogDir:currentBlog], curPath];
		NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
		NSString *urlStr = [self pictureURLForPicturePathBySendingToServer:filePAth];
		[urlStr retain];
		[ap release];
		[urlStr autorelease];
		if( !urlStr )
			return NO;
		else 
		{
			NSString *imgTag = [self imageTagForPath:curPath andURL:urlStr];
			if (firstImage) {
				desc = [desc  stringByAppendingString:@"\n<p>"];
				paraOpen = YES;
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlStr, imgTag]];
				firstImage = NO;
			} else {
				
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<br /><br /><a href=\"%@\">%@</a>",urlStr, imgTag]];
			}
			[self deleteImageNamed:curPath forBlog:currentBlog];
			[photos removeLastObject];
		}
	}
	
	if (paraOpen)
		desc = [desc  stringByAppendingString:@"</p>"];
	
	[aPost setObject:desc forKey:@"description"];
	
	return YES;
}

- (BOOL)appendImagesOfCurrentPostToDescription
{
	NSMutableArray *photos = [currentPost valueForKey:@"Photos"];
	int i, count = [photos count];
	NSString *curPath = nil;
	
	NSString *desc = [currentPost valueForKey:@"description"];
	BOOL firstImage = YES;
	BOOL paraOpen = NO;

	for( i=count-1; i >=0 ; i-- )
	{
		curPath = [photos objectAtIndex:i];
		NSString *filePAth = [NSString stringWithFormat:@"%@/%@",[self blogDir:currentBlog], curPath];
		NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
		NSString *urlStr = [self pictureURLForPicturePathBySendingToServer:filePAth];
		[urlStr retain];
		[ap release];
		[urlStr autorelease];
		if( !urlStr )
			return NO;
		else 
		{
			NSString *imgTag = [self imageTagForPath:curPath andURL:urlStr];
			if (firstImage) {
				desc = [desc  stringByAppendingString:@"\n<p>"];
				paraOpen = YES;
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlStr, imgTag]];
				firstImage = NO;
			} else {
			
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<br /><br /><a href=\"%@\">%@</a>",urlStr, imgTag]];
			}
			[self deleteImageNamed:curPath forBlog:currentBlog];
			[photos removeLastObject];
		}
	}
	
	if (paraOpen)
		desc = [desc  stringByAppendingString:@"</p>"];
	
	[currentPost setObject:desc forKey:@"description"];
	
	
	return YES;
}

- (BOOL)appendImagesOfCurrentPageToDescription
{
	NSMutableArray *photos = [currentPage valueForKey:@"Photos"];
	int i, count = [photos count];
	NSString *curPath = nil;
	
	NSString *desc = [currentPage valueForKey:@"description"];
	desc = (desc == nil ? @"" : desc );
	BOOL firstImage = YES;
	BOOL paraOpen = NO;
	
	for( i=count-1; i >=0 ; i-- )
	{
		curPath = [photos objectAtIndex:i];
		NSString *filePAth = [NSString stringWithFormat:@"%@/%@",[self blogDir:currentBlog], curPath];
		NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
		NSString *urlStr = [self pagePictureURLForPicturePathBySendingToServer:filePAth];
		[urlStr retain];
		[ap release];
		[urlStr autorelease];
		if( !urlStr )
			return NO;
		else 
		{
			NSString *imgTag = [self imageTagForPath:curPath andURL:urlStr];
			if (firstImage) {
				desc = [desc  stringByAppendingString:@"\n<p>"];
				paraOpen = YES;
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlStr, imgTag]];
				firstImage = NO;
			} else {
				
				desc = [desc stringByAppendingString:[NSString stringWithFormat:@"<br /><br /><a href=\"%@\">%@</a>",urlStr, imgTag]];
			}
			[self deleteImageNamed:curPath forBlog:currentBlog];
			[photos removeLastObject];
		}
	}
	
	if (paraOpen)
		desc = [desc  stringByAppendingString:@"</p>"];

	[currentPage setObject:desc forKey:@"description"];
	
	
	return YES;
}

#pragma mark File Paths

//TODO: Why can't we create complete folder structure when we save the blog?
// So that we can reduse the file system references.
- (NSString *)blogDir:(id)aBlog
{
	NSString *blogHostDir = [currentDirectoryPath stringByAppendingPathComponent:[aBlog objectForKey:@"blog_host_name"]];
	// note that when the local drafts is set as current blog, a fake blogid "localdrafts" is used
	// this will resolve to a dir called "localdrafts" which is what we want
	NSString *blogDir = [blogHostDir stringByAppendingPathComponent:[aBlog objectForKey:@"blogid"]];
	NSString *localDraftsDir = [blogDir stringByAppendingPathComponent:@"localDrafts"];


	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	if( !([fm fileExistsAtPath:blogDir isDirectory:&isDirectory] && isDirectory) )
	{
		// [fm createDirectoryAtPath:blogHostDir attributes:nil];
		[fm createDirectoryAtPath:blogHostDir withIntermediateDirectories:YES attributes:nil error:nil];
		[fm createDirectoryAtPath:blogDir attributes:nil];
		[fm createDirectoryAtPath:localDraftsDir attributes:nil];
	}
	return blogDir;
}

- (NSString *)templatePathForBlog:(id)aBlog
{
	return [NSString stringWithFormat:@"%@/template.html",[self blogDir:aBlog]];
}

- (NSString *)autoSavePathForTheCurrentBlog
{
	return [[self blogDir:currentBlog] stringByAppendingFormat:@"/autoSavedPost.archive"];
}

- (BOOL)clearAutoSavedContext
{
	id aPost = [self autoSavedPostForCurrentBlog];
	[self deleteAllPhotosForPost:aPost forBlog:currentBlog];
	
	NSString *fp = [self autoSavePathForTheCurrentBlog];
	if( fp )
		return [[NSFileManager defaultManager] removeItemAtPath:fp error:NULL];
	
	return NO;	
}

- (BOOL)removeAutoSavedCurrentPostFile
{
	NSString *fp = [self autoSavePathForTheCurrentBlog];
	if( fp )
		return [[NSFileManager defaultManager] removeItemAtPath:fp error:NULL];
	
	return YES;
}

- (NSString *)pathToPostTitles:(id)aBlog
{
	NSString *pathToPostTitles = [[self blogDir:aBlog] stringByAppendingPathComponent:@"postTitles.archive"];	
	return pathToPostTitles;
}

- (NSString *)pathToCommentTitles:(id)aBlog
{
	NSString *pathToCommentTitles = [[self blogDir:aBlog] stringByAppendingPathComponent:@"commentTitles.archive"];	
	return pathToCommentTitles;
}
- (NSString *)pathToPageTitles:(id)aBlog
{
	NSString *pathToPageTitles = [[self blogDir:aBlog] stringByAppendingPathComponent:@"pageTitles.archive"];	
	return pathToPageTitles;
}

- (NSString *)pathToPost:(id)aPost forBlog:(id)aBlog
{
	NSString *pathToPost = [[self blogDir:aBlog] stringByAppendingPathComponent:[self postFileName:aPost]];
	return pathToPost;
}

- (NSString *)draftsPathForBlog:(id)aBlog
{
	NSString *draftsPath = [[self blogDir:aBlog] stringByAppendingPathComponent:@"localDrafts"];	
	return draftsPath;
}

- (NSString *)pathToDraftTitlesForBlog:(id)aBlog
{
	NSString *pathToDraftTitles = [[self draftsPathForBlog:aBlog] stringByAppendingPathComponent:@"draftTitles.archive"];	
	return pathToDraftTitles;
}


- (NSString *)pageDraftsPathForBlog:(id)aBlog
{
	NSString *pagesDraftsDir = [[self blogDir:aBlog] stringByAppendingPathComponent:@"Pages"];
	NSString *pageslocalDraftsDir = [[self blogDir:aBlog] stringByAppendingPathComponent:@"Pages/localDrafts"];
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	if( !([fm fileExistsAtPath:pagesDraftsDir isDirectory:&isDirectory] && isDirectory) )
	{
		[fm createDirectoryAtPath:pagesDraftsDir attributes:nil];
	}
	if( !([fm fileExistsAtPath:pageslocalDraftsDir isDirectory:&isDirectory] && isDirectory) )
	{
		[fm createDirectoryAtPath:pageslocalDraftsDir attributes:nil];
	}
	
	NSString *pageDraftsPath = [[self blogDir:aBlog] stringByAppendingPathComponent:@"Pages/localDrafts"];	

	return pageDraftsPath;
}

- (NSString *)pathToPageDraftTitlesForBlog:(id)aBlog
{
	NSString *pathToDraftTitles = [[self pageDraftsPathForBlog:aBlog] stringByAppendingPathComponent:@"draftTitles.archive"];	
	return pathToDraftTitles;
}



- (NSString *)pathToDraft:(id)aDraft forBlog:(id)aBlog
{
	NSString *draftid = [aDraft valueForKey:@"draftid"];
	NSString *draftFileName = [NSString stringWithFormat:@"draft.%@.archive", draftid];
	NSString *pathToDraft = [[self draftsPathForBlog:aBlog] stringByAppendingPathComponent:draftFileName];
	
	return pathToDraft;
}

- (NSString *)pathToPageDraft:(id)aDraft forBlog:(id)aBlog
{
	NSString *draftid = [aDraft valueForKey:@"pageDraftid"];
	NSString *draftFileName = [NSString stringWithFormat:@"draft.%@.archive", draftid];
	NSString *pathToPageDraft = [[self pageDraftsPathForBlog:aBlog] stringByAppendingPathComponent:draftFileName];
	
	return pathToPageDraft;
}


- (NSString *)postFileName:(id)aPost 
{
	NSString *postid = [aPost valueForKey:@"postid"];
	NSString *postFileName = [NSString stringWithFormat:@"post.%@.archive", postid];
	return postFileName;
}

- (NSString *)commentsFolderPathForBlog:(id)aBlog
{
	NSString *commentsFolderPath = [[self blogDir:aBlog] stringByAppendingPathComponent:@"Comments"];	
	return commentsFolderPath;
}

- (NSString *)commentFilePath:(id)aComment forBlog:(id)aBlog
{
	NSString *comment_id = [aComment valueForKey:@"comment_id"];
	NSString *commentFileName = [NSString stringWithFormat:@"comment.%@.archive", comment_id];
	NSString *commentFilePath = [[self blogDir:aBlog] stringByAppendingPathComponent:commentFileName];
	return commentFilePath;
}

- (NSString *)pageFilePath:(id)aPage forBlog:(id)aBlog
{
	NSString *page_id = [aPage valueForKey:@"page_id"];
	NSString *pageFileName = [NSString stringWithFormat:@"page.%@.archive", page_id];
	NSString *pageFilePath = [[self blogDir:aBlog] stringByAppendingPathComponent:pageFileName];
	return pageFilePath;
}


#pragma mark -
#pragma mark Blog metadata

- (NSArray *)blogFieldNames {
	
	if (!blogFieldNames) {

		self->blogFieldNames = [NSArray arrayWithObjects:@"url", @"username", @"blog_host_name",@"blog_host_software",
														@"isAdmin",@"blogid",@"blogName",@"xmlrpc",
														@"nickname",@"userid",@"lastname",@"firstname",
														@"newposts",@"totalposts",
														@"newcomments",@"totalcomments", @"xmlrpcsuffix",@"pwd", kPostsDownloadCount, nil];
		[blogFieldNames retain];
	
	}
	
	return blogFieldNames;
}



- (NSDictionary *)blogFieldNamesByTag {
	
	if(!blogFieldNamesByTag) {
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
		NSNumber *tag15 = [NSNumber numberWithInt:115];
		NSNumber *tag16 = [NSNumber numberWithInt:116];
		NSNumber *tag17 = [NSNumber numberWithInt:117];
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, tag9, tag10, 
							tag11,tag12,tag13,tag14,tag15,tag16, tag17, nil];
		self->blogFieldNamesByTag = [NSDictionary dictionaryWithObjects:[self blogFieldNames] forKeys:tags];
		
		[blogFieldNamesByTag retain];

	}

	return blogFieldNamesByTag;
}

- (NSDictionary *)blogFieldTagsByName {
	
	if(!blogFieldTagsByName) {
		
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
		NSNumber *tag15 = [NSNumber numberWithInt:115];
		NSNumber *tag16 = [NSNumber numberWithInt:116];
		NSNumber *tag17 = [NSNumber numberWithInt:117];
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, tag9, tag10,
							tag11,tag12,tag13,tag14,tag15, tag16, tag17, nil];
		self->blogFieldTagsByName = [NSDictionary dictionaryWithObjects:tags forKeys:[self blogFieldNames]];
		
		[blogFieldTagsByName retain];
		
	}
	
	return blogFieldTagsByName;
}


#pragma mark Blog data

- (NSString *)xmlurl:(NSString *)hosturl
{
	//Handeled if HostUrl is nil from server.
	if(!hosturl)
		return nil;
	
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:hosturl]
											  cachePolicy:NSURLRequestUseProtocolCachePolicy							  
										  timeoutInterval:60.0];			
	NSData *data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:NULL error:NULL];
	
	// NSString *xmlstr = [NSString stringWithUTF8String:[data bytes]];
	NSString *xmlstr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	if( [data length] > 0 )
	{
		NSRange range1 = [xmlstr rangeOfString:@"preferred=\"true\""];
		if (range1.location != NSNotFound) {
			NSRange lr1 = NSMakeRange(range1.location, [xmlstr length]-range1.location);
			
			NSRange endRange1 = [xmlstr rangeOfString:@"/>" options:NSLiteralSearch range:lr1];
			if (endRange1.location != NSNotFound) {
				NSString *ourStr = [xmlstr substringWithRange:NSMakeRange(range1.location, endRange1.location-range1.location)];
				
				ourStr = [ourStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				ourStr = [ourStr substringWithRange:NSMakeRange(0, [ourStr length]-1)];
				NSRange r1 = [ourStr rangeOfString:@"\"" options:NSBackwardsSearch];
				if (r1.location != NSNotFound) {
					NSString *xmlrpcurl = [ourStr substringWithRange:NSMakeRange(r1.location+1, [ourStr length]-r1.location-1)];			
					return xmlrpcurl;
				}
			}
		}
	}
	return nil;
}

- (NSString *)discoverxmlrpcurlForurl:(NSString *)urlstr
{
	if ( ![urlstr hasPrefix:@"http"] )
		urlstr = [NSString stringWithFormat:@"http://%@", urlstr];
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:urlstr]
											  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData   
										  timeoutInterval:60.0]; 
	
	NSError *error = nil;
	NSHTTPURLResponse *response = nil;
	NSData *data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&response error:&error];
	if ( error != nil )
	
	if ( [response statusCode] != 200 ) {
		NSError *responseError = [NSError errorWithDomain:NSPOSIXErrorDomain code:1 userInfo:nil];
		return (id)responseError;
	}
	
	if( [data length] > 0 )
	{
			NSString *htmlStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			if ( !htmlStr ) { // Handle the Servers which send Non UTF-8 Strings
				htmlStr = [[[NSString alloc] initWithData:data encoding:[NSString defaultCStringEncoding]] autorelease];
				data = [htmlStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			}	

			NSError *parseError = nil;
			WPXMLReader *xmlReader = [[[WPXMLReader alloc] init] autorelease];
			[xmlReader parseXMLData:data parseError:&parseError];
			NSString *hosturl = xmlReader.hostUrl;
			return [self xmlurl:hosturl];
		}
	return nil;
}	
- (BOOL)validateCurrentBlog:(NSString *)url user:(NSString *)username password:(NSString*)pwd 
{	
	NSString *blogURL = [NSString stringWithFormat:@"http://%@", url];
	NSString *xmlrpc = [self discoverxmlrpcurlForurl:url];

	if ( [xmlrpc isKindOfClass:[NSError class]] || !xmlrpc) {
		xmlrpc = [blogURL stringByAppendingString:[currentBlog valueForKey:@"xmlrpcsuffix"]];
	}
	//  ------------------------- invoke login & getUserInfo
	
	XMLRPCRequest *reqUserInfo = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[reqUserInfo setMethod:@"blogger.getUserInfo" withObjects:[NSArray arrayWithObjects:@"ABCDEF012345",username,pwd,nil]];
	
	NSDictionary *userInfo = [self executeXMLRPCRequest:reqUserInfo byHandlingError:YES];
	[reqUserInfo release];
	
	if( ![userInfo isKindOfClass:[NSDictionary class]] ) //err occured.
		return NO;
	return YES;
}

- (int)checkXML_RPC_URL_IsRunningSupportedVersionOfWordPress:(NSString *)xmlrpcurl withPagesAndCommentsSupport:(BOOL *) isPagesAndCommentsSupported
{
	XMLRPCRequest *listMethodsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpcurl]];
	[listMethodsReq setMethod:@"system.listMethods" withObjects:[NSArray array]];
	NSArray *listOfMethods = [self executeXMLRPCRequest:listMethodsReq byHandlingError:YES];
	[listMethodsReq release];
	
	* isPagesAndCommentsSupported = NO;

	if( [listOfMethods isKindOfClass:[NSError class]] )
		return -1;
		
	if( [listOfMethods containsObject:@"wp.getPostStatusList"] && [listOfMethods containsObject:@"blogger.getUserInfo"] && 
	   [listOfMethods containsObject:@"metaWeblog.newMediaObject"] && [listOfMethods containsObject:@"blogger.getUsersBlogs"] &&
	   [listOfMethods containsObject:@"wp.getAuthors"] && [listOfMethods containsObject:@"metaWeblog.getRecentPosts"] &&
	   [listOfMethods containsObject:@"metaWeblog.getPost"] &&
	   [listOfMethods containsObject:@"wp.getOptions"] &&
	   [listOfMethods containsObject:@"metaWeblog.newPost"] && [listOfMethods containsObject:@"metaWeblog.editPost"] &&
	   [listOfMethods containsObject:@"metaWeblog.deletePost"] && [listOfMethods containsObject:@"wp.newCategory"] &&
	   [listOfMethods containsObject:@"wp.deleteCategory"] && [listOfMethods containsObject:@"wp.getCategories"] ) {


		if ( [listOfMethods containsObject:@"wp.getComments"] && [listOfMethods containsObject:@"wp.getPages"] )
			*isPagesAndCommentsSupported = YES;
		return 1;
	}	
	
	return 0;
}

/*
 Get blog data from host
 */
- (BOOL) refreshCurrentBlog:(NSString *)url user:(NSString *)username password:(NSString*)pwd 
{	
	// REFACTOR login method in BlogDetailModalViewControler so that all XML rpc interaction is handled from here
	// report exceptions back to caller
	// 1. test connection and xmlrpc call using blogger.getUserInfo
	// 2. update current blog with user info
	// 3. getUsersBlogs
	// 4. getAuthors
	// 5. get Categories
	// 6. get Statuses
	
	// Can have multiple usernames registered for the same blog
	NSString *blogHost = [NSString stringWithFormat:@"%@_%@", username, url];
	
	// Important: This is the only place where blog_host_name should be set
	// We use this as the blog folder name
	[currentBlog setValue:blogHost forKey:@"blog_host_name"];
	
	NSString *blogURL = [NSString stringWithFormat:@"http://%@", url];
	[currentBlog setValue:(blogURL?blogURL:@"") forKey:@"url"];
	
	NSString *xmlrpc = [self discoverxmlrpcurlForurl:url];
	
	if ([xmlrpc isKindOfClass:[NSError class]]) {
		UIAlertView *rsdError = [[UIAlertView alloc] initWithTitle:@"We could not find your blog. Please check the URL, Network Connection and try again.If the problem persists, please visit \"iphone.wordpress.org\" to report the problem."
														   message:nil
														  delegate:[[UIApplication sharedApplication] delegate]
												 cancelButtonTitle:@"Visit Site"
												 otherButtonTitles:@"OK", nil];
		
		rsdError.tag = kRSDErrorTag;
		[rsdError show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		[rsdError release];
		return NO;
		
	}

	if (!xmlrpc) {
		UIAlertView *rsdError = [[UIAlertView alloc] initWithTitle:@"We could not find the XML-RPC service for your blog. Please check your network connection and try again. if the problem persists, please visit \"iphone.wordpress.org\" to report the problem."
																	   message:nil
																	  delegate:[[UIApplication sharedApplication] delegate]
															 cancelButtonTitle:@"Visit Site"
															 otherButtonTitles:@"OK", nil];
		rsdError.tag = kRSDErrorTag;
		[rsdError show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		[rsdError release];
		return NO;
	}
	
	BOOL supportsPagesAndComments;
	int versionCheck = [self checkXML_RPC_URL_IsRunningSupportedVersionOfWordPress: xmlrpc withPagesAndCommentsSupport:&supportsPagesAndComments];
	if( versionCheck < 0 )
		return NO;
	if( versionCheck == 0 )
	{
		UIAlertView *unsupportedWordpress = [[UIAlertView alloc] initWithTitle:@"Sorry, you appear to be running an older version of WordPress that is not supported by this app. Please visit \"iphone.wordpress.org\" for details."
																	   message:nil
																	  delegate:[[UIApplication sharedApplication] delegate]
															 cancelButtonTitle:@"Visit Site"
															 otherButtonTitles:@"OK", nil];
		unsupportedWordpress.tag = kUnsupportedWordpressVersionTag;
		[unsupportedWordpress show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];

		[unsupportedWordpress release];
		return NO;
	}
	
	[currentBlog setValue:[NSNumber numberWithBool:supportsPagesAndComments]   forKey:kSupportsPagesAndComments];

	[currentBlog setValue:xmlrpc?xmlrpc:@"" forKey:@"xmlrpc"];
	[currentBlog setValue:(username?username:@"") forKey:@"username"];
	
	//  ------------------------- invoke login & getUserInfo
	
	
	XMLRPCRequest *reqUserInfo = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[reqUserInfo setMethod:@"blogger.getUserInfo" withObjects:[NSArray arrayWithObjects:@"ABCDEF012345",username,pwd,nil]];
	
	NSDictionary *userInfo = [self executeXMLRPCRequest:reqUserInfo byHandlingError:YES];
	[reqUserInfo release];
	
	if( ![userInfo isKindOfClass:[NSDictionary class]] ) //err occured.
		return NO;

	// save values returned by getUserInfo into current blog
	NSString *nickname = [userInfo valueForKey:@"nickname"];
	[currentBlog setValue:nickname?nickname:@"" forKey:@"nickname"];
	
	NSString *userid = [userInfo valueForKey:@"userid"];
	[currentBlog setValue:userid?userid:@"" forKey:@"userid"];
	
	NSString *lastname = [userInfo valueForKey:@"lastname"];
	[currentBlog setValue:lastname?lastname:@"" forKey:@"lastname"];
	
	NSString *firstname = [userInfo valueForKey:@"firstname"];
	[currentBlog setValue:firstname?firstname:@"" forKey:@"firstname"];
	
	// ------------------------------invoke blogger.getUsersBlogs
	
	XMLRPCRequest *reqUsersBlogs = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[reqUsersBlogs setMethod:@"blogger.getUsersBlogs" withObjects:[NSArray arrayWithObjects:@"ABCDEF012345",username,pwd,nil]];

	// we are expecting an array to be returned in the response with one dictionary containing 
	// the blog located by url used at login
	// If there is a fault, the returned object will be a dictionary with a fault element.
	// If the returned object is a NSArray, the, the object at index 0 will be the dictionary with blog info fields
	
	NSArray *usersBlogsResponseArray = [self executeXMLRPCRequest:reqUsersBlogs byHandlingError:YES];
	[reqUsersBlogs release];
	if( ![usersBlogsResponseArray isKindOfClass:[NSArray class]] )
		return NO;

	NSDictionary *usersBlogs = [usersBlogsResponseArray objectAtIndex:0];

	// load blog fields into currentBlog
	NSString *blogid = [usersBlogs valueForKey:@"blogid"];
	[currentBlog setValue:blogid?blogid:@"" forKey:@"blogid"];
	
	
	XMLRPCRequest *reqOptionsBlogs = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[reqOptionsBlogs setMethod:@"wp.getOptions" withObjects:[NSArray arrayWithObjects:blogid,username,pwd,nil]];
	NSDictionary *optionsDict = [self executeXMLRPCRequest:reqOptionsBlogs byHandlingError:YES];
	if( ![optionsDict isKindOfClass:[NSDictionary class]] )
		return NO;
	
	/*
	 NSString *adminStr	= [usersBlogs valueForKey:@"isAdmin"];
	 NSNumber *isAdmin = [NSNumber numberWithBool:(BOOL) (adminStr == kCFBooleanTrue)?YES:NO) ];
	 */
	[currentBlog setValue:@"" forKey:@"isAdmin"];
	
	NSString *blogName = [[optionsDict valueForKey:@"blog_title"]valueForKey:@"value"];
	[currentBlog setValue:blogName?blogName:@"" forKey:@"blogName"];

	
	
	// Do not use this value
	//NSString *xmlrpc = url;//[usersBlogs valueForKey:@"xmlrpc"];
	//[currentBlog setValue:xmlrpc?xmlrpc:@"" forKey:@"xmlrpc"];
	
	// use the default value from the blog
	// if RSD failed to find the endpoint
	if (!xmlrpc) {
		xmlrpc = [usersBlogs valueForKey:@"xmlrpc"];
		[currentBlog setValue:xmlrpc?xmlrpc:@"" forKey:@"xmlrpc"];
	}
	
	
	
	
	
	// ----------------------------------------------  retrieve blog categories 
	
	// response will be array of category dictionaries
	
	// invoke wp.getCategories
	XMLRPCRequest *reqCategories = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[reqCategories setMethod:@"wp.getCategories" withObjects:[NSArray arrayWithObjects:blogid,username,pwd,nil]];
	
	NSArray *categories = [self executeXMLRPCRequest:reqCategories byHandlingError:YES];
	[reqCategories release];
	if( [categories isKindOfClass:[NSArray class]])
	{
		
		// categoryName if blank will be set to id
		
		NSMutableArray *cats = [NSMutableArray arrayWithCapacity:15];
		
		for (NSDictionary *category in categories) {
			
			NSString *categoryId = [category valueForKey:@"categoryId"];
			NSString *categoryName = [category valueForKey:@"categoryName"];
			
			if (categoryName == nil || [categoryName isEqualToString:@""] ) {
				
				NSMutableDictionary *cat = [[category mutableCopy] retain];
				[cat setObject:categoryId forKey:@"categoryName"];
				[cats addObject:cat];
				[cat release];
			
			} else {
				
				[cats addObject:category];
			
			}
				
		
			
		}
		
		[currentBlog setObject:cats forKey:@"categories"];
		
		
	}
	else {
		return NO;
	}
	
	// retrieve blog authors 
	// response will be array of author dictionaries
	
	// invoke wp.getAuthors
	XMLRPCRequest *getAuthorsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[getAuthorsReq setMethod:@"wp.getAuthors" withObjects:[NSArray arrayWithObjects:blogid,username,pwd,nil]];
	NSArray *authors = [self executeXMLRPCRequest:getAuthorsReq byHandlingError:YES];
	[getAuthorsReq release];
	if( [authors isKindOfClass:[NSArray class]] ) //might be an error.
	{
		[currentBlog setObject:authors forKey:@"authors"];
	}
	else {
		return NO;
	}
	
	// invoke wp.getPostStatusList	
	XMLRPCRequest *getPostStatusListReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[getPostStatusListReq setMethod:@"wp.getPostStatusList" withObjects:[NSArray arrayWithObjects:blogid,username,pwd,nil]];
	NSDictionary *postStatusList = [self executeXMLRPCRequest:getPostStatusListReq byHandlingError:YES];
	[getPostStatusListReq release];
	if( [postStatusList isKindOfClass:[NSDictionary class]] ) //might be an error.
		//keys are actual values, values are display strings.
	{
		[currentBlog setObject:postStatusList forKey:@"postStatusList"];
	}
	else {
		return NO;
	}
	// invoke wp. getPageStatusList	
	XMLRPCRequest *getPageStatusListReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:xmlrpc]];
	[getPageStatusListReq setMethod:@"wp.getPageStatusList" withObjects:[NSArray arrayWithObjects:blogid,username,pwd,nil]];
	NSDictionary *pageStatusList = [self executeXMLRPCRequest:getPageStatusListReq byHandlingError:YES];
	[getPageStatusListReq release];
	if( [pageStatusList isKindOfClass:[NSDictionary class]] ) //might be an error.
		//keys are actual values, values are display strings.
	{
		[currentBlog setObject:pageStatusList forKey:@"pageStatusList"];
	}
	else {
		return NO;
	}
	
	return YES;
}


- (void)deletedPostsForExistingPosts:(NSMutableArray *)ePosts ofBlog:(id)aBlog andNewPosts:(NSArray *)nPosts
{

	NSMutableArray *ePostIds = [[ePosts valueForKey:@"postid"] mutableCopy];
	NSArray *nPostIds = [nPosts valueForKey:@"postid"];
	

	id curPost = nil;
	
	int i =0, count = [ePostIds count];
	for( i=count-1; i >=0; i-- )
	{
		if( ![nPostIds containsObject:[ePostIds objectAtIndex:i]] )
		{
			curPost = [ePosts objectAtIndex:i];

			if( ![[curPost valueForKey:@"hasChanges"] boolValue] )
			{
				NSString *pPath = [self pathToPost:curPost forBlog:aBlog];
				if( [[NSFileManager defaultManager] removeItemAtPath:pPath error:NULL] )
				{
					[ePosts removeObjectAtIndex:i];
				}
			}
		}
	}
	
	[ePostIds release];
}


/* SYNC POSTS FOR BLOG
 ** leave UI state alone until download is resolved - update posts and postTitlesList on file system
 ** after the sync is completed, UI controllers which initiated the request will refresh their states by
	- setting a current blog
	- setting posts list
	- reloading data in tables
	- redisplaying views
 ** In our hierarchical nav model we have blogs list and posts list in the UI. When refresh is
    launched form posts lists and the user returns to blogs list, blogs data must be refreshed for revised counts.
    Toggle a flag on blogs list viewDidAppear to know if we returned there from a posts list drill down.
 
 ** We do not have update dates on posts in metaWeblog.getRecentPosts
    - strategy will be to keep adding new posts and updating existing ones that arrive in recent posts.
    - need to have an api to get recentlyupdated posts rather than n number of recent posts
 
 */


- (BOOL) syncPostsForCurrentBlog {
	
	if( isLocaDraftsCurrent )
		return NO;
	[currentBlog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];

	[self syncPostsForBlog:currentBlog];
	[currentBlog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];

	[self makeBlogAtIndexCurrent:currentBlogIndex];

	return YES;
	
}

// sync posts for a given blog
- (BOOL) syncPostsForBlog:(id)blog {
	if( [[blog valueForKey:@"blogid"] isEqualToString:kDraftsBlogIdStr] )
		return NO;
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	NSNumber *maxToFetch =  [NSNumber numberWithInt:[[[currentBlog valueForKey:kPostsDownloadCount] substringToIndex:2] intValue]];
	
	
	//  ------------------------- invoke metaWeblog.getRecentPosts
	XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
	[postsReq setMethod:@"metaWeblog.getRecentPosts" 
			withObjects:[NSArray arrayWithObjects:blogid,username, pwd, maxToFetch, nil]];
	
	NSArray *recentPostsList = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
	[postsReq release];
	// TODO:
	// Check for fault
	// check for nil or empty response
	// provide meaningful messge to user
	if ((!recentPostsList) || !([recentPostsList isKindOfClass:[NSArray class]]) ) {
		[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//		[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
		return NO;
	}
	
	// loop through each post
	// - add local_status, blogid and bloghost to the pos
	// - save the post
	// - count new posts
	// - add/replace postTitle for post 
	// Sort and Save postTitles list
	// Update blog counts and save blogs list	
	
	// get post titles from file
	NSMutableArray *newPostTitlesList;
	NSString *postTitlesPath = [self pathToPostTitles:blog];
	NSFileManager *fm = [NSFileManager defaultManager];

	if([fm fileExistsAtPath:postTitlesPath])
	{
		newPostTitlesList = [NSMutableArray arrayWithContentsOfFile:postTitlesPath];
    } else {
		newPostTitlesList = [NSMutableArray arrayWithCapacity:30];
	}
	
	// loop thru posts list
	NSEnumerator *postsEnum = [recentPostsList objectEnumerator];
	NSDictionary *post;
	NSInteger newPostCount = 0;
	[newPostTitlesList removeAllObjects];	
	while (post = [postsEnum nextObject] ) {
		
		// add blogid and blog_host_name to post
	
		NSDate* postGMTDate=[post valueForKey:@"date_created_gmt"];
		NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:postGMTDate];
		NSDate *currentDate = [postGMTDate addTimeInterval:(secs*+1)];
		[post setValue:currentDate forKey:@"date_created_gmt"];

		[post setValue:[blog valueForKey:@"blogid"] forKey:@"blogid"];
		[post setValue:[blog valueForKey:@"blog_host_name"] forKey:@"blog_host_name"];

		
		// Check if the post already exists 
		// yes: check if a local draft exists
		//		 yes: set the local-status to 'edit'
		//		 no: set the local_status to 'original'
		// no: increment new posts count
		
		NSString *pathToPost = [self pathToPost:post forBlog:blog];
		
		if([fm fileExistsAtPath:pathToPost]) {
			
			//TODO: if we implement drafts as a logical blog we may not need this logic any more.
//			if([fm fileExistsAtPath:pathToDraft]) {
//				[post setValue:@"edit" forKey:@"local_status"];
//			} else {
//				[post setValue:@"original" forKey:@"local_status"];
//			}
		
		} else {
			[post setValue:@"original" forKey:@"local_status"];
			newPostCount++ ;
		}

		// write the new post
		[post writeToFile:pathToPost atomically:YES];
		
		// make a post title using the post
		NSMutableDictionary *postTitle = [self postTitleForPost:post];
		
		// delete existing postTitle and add new post title to list
		NSInteger index = [self indexOfPostTitle:postTitle inList:(NSArray *)newPostTitlesList];
		if (index != -1 ) {
			[newPostTitlesList removeObjectAtIndex:index];		
		} 
		[newPostTitlesList addObject:postTitle];

		
	}
	
	[self deletedPostsForExistingPosts:newPostTitlesList ofBlog:currentBlog andNewPosts:recentPostsList];

	
	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[newPostTitlesList sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	[newPostTitlesList writeToFile:[self pathToPostTitles:blog]  atomically:YES];
	// increment blog counts and save blogs list
	[blog setObject:[NSNumber numberWithInt:[newPostTitlesList count]] forKey:@"totalposts"];
	[blog setObject:[NSNumber numberWithInt:newPostCount] forKey:@"newposts"];
	NSInteger blogIndex = [self indexForBlogid:[blog valueForKey:@"blogid"] hostName:[blog valueForKey:@"blog_host_name"]];
	if (blogIndex >= 0) {
		[self->blogsList replaceObjectAtIndex:blogIndex withObject:blog];
		
	} else {
//		[self->blogsList addObject:blog];
	}

//Commented code as per ticket#102	
//	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//
//	[self saveBlogData];

//	[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
	[self performSelectorOnMainThread:@selector(postBlogsRefreshNotificationInMainThread:) withObject:blog waitUntilDone:NO];
	return YES;
}

- (void)postBlogsRefreshNotificationInMainThread:(id)blog
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
}

// loads blogs for each host that has been defined
-(void)loadBlogData {

	// look for blogs.archive file under wordpress (the currrent dir), look for blogs.archive file
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *blogsArchiveFilePath = [currentDirectoryPath stringByAppendingPathComponent:@"blogs.archive"];
	
	
	if ([fileManager fileExistsAtPath:blogsArchiveFilePath]) {
		// set method will release, make mutable copy and retain
		NSMutableArray *arr = [[NSKeyedUnarchiver unarchiveObjectWithFile:blogsArchiveFilePath] mutableCopy];
		[self setBlogsList:arr];
		[arr release];
	} 
	else{
		NSMutableArray * nBlogs = [NSMutableArray array];
		[self setBlogsList:nBlogs];
		[self saveBlogData];
	}
	

}

-(void)sortBlogData {
	
	if (blogsList.count) {
		
		
		// Create a descriptor to sort blog dictionaries by blogName
		NSSortDescriptor *blognameSortDescriptor =  [[NSSortDescriptor alloc] 
													 initWithKey:@"blogName" ascending:YES
													 selector:@selector(localizedCaseInsensitiveCompare:)];
		NSArray *sortDescriptors = [NSArray arrayWithObjects:blognameSortDescriptor, nil];
		[blogsList sortUsingDescriptors:sortDescriptors];
		[blognameSortDescriptor release];		
	}

}

- (void)saveBlogData {
	
	NSString *blogsArchiveFilePath = [currentDirectoryPath stringByAppendingPathComponent:@"blogs.archive"];
	// Empty blogs list may signify all blogs at launch were deleted;  
	// check for existence of prior archive before saving
	if ([blogsList count] || ([[NSFileManager defaultManager] fileExistsAtPath:blogsArchiveFilePath])) {
		[NSKeyedArchiver archiveRootObject:blogsList toFile:blogsArchiveFilePath];
	} else {
		WPLog(@"No blogs in list. there is nothing to save!");
	}
	
	
	
}

/*
-(void)createDemoBlogData {
	
	// MAKE SAMPLE BLOG 1
	
	NSArray *names = [[BlogDataManager sharedDataManager] blogFieldNames];
	
	NSNumber *initCount = [NSNumber numberWithInt:0];
	NSArray *values = [NSArray arrayWithObjects:@"ganeshr.wordpress.com", @"ganeshr", @"wordpress.com",@"wordpress.org",
													@"1", @"3737428", @"Ganesh Weblog", @"http://ganeshr.wordpress.com/xmlrpc.php",
							@"ganeshr",@"3975991",@"Ramachandran",@"Ganesh",initCount,initCount,initCount,initCount, 
								@"/xmlrpc.php", @"pass", nil];
	NSMutableDictionary *aBlogDict = [NSMutableDictionary dictionaryWithObjects:values forKeys:names];
	[blogsList addObject:aBlogDict];
	
	
	// MAKE SAMPLE BLOG 2
	NSArray *values2 = [NSArray arrayWithObjects:@"effigentiphone.wordpress.com", @"ganeshr", @"wordpress.com",@"wordpress.org",
						@"1", @"3738567", @"Effigent iPhone Project", @"http://effigentiphone.wordpress.com/xmlrpc.php",
						@"ganeshr",@"3975991",@"Ramachandran",@"Ganesh",initCount,initCount,initCount,initCount, 
							@"/xmlrpc.php", @"pass", nil];
	
	aBlogDict = [NSMutableDictionary dictionaryWithObjects:values2 forKeys:names];
	[blogsList addObject:aBlogDict];
	
	
	// Sort and archive the sample data
	[self sortBlogData];
	[self saveBlogData];
}
*/
- (void) loadPhotosDB 
{
	NSString *photosArchiveFilePath = [self.currentDirectoryPath stringByAppendingPathComponent:@"wordpress.photos"];
	// Empty photos list may signify all photos at launch were deleted;  
	// check for existence of prior archive before saving
	if ([[NSFileManager defaultManager] fileExistsAtPath:photosArchiveFilePath]) {
		
		[self setPhotosDB:[NSKeyedUnarchiver unarchiveObjectWithFile:photosArchiveFilePath]];
		
	} else {
		[[NSFileManager defaultManager] createDirectoryAtPath:[currentDirectoryPath stringByAppendingString:@"/Pictures"] attributes:nil];
		NSMutableArray *tempArray = [[NSMutableArray alloc] init];
		[self setPhotosDB:tempArray];
		[tempArray release];
	}		
}

- (void) savePhotosDB {
	NSString *photosArchiveFilePath = [self.currentDirectoryPath stringByAppendingPathComponent:@"wordpress.photos"];
	// Empty photos list may signify all photos at launch were deleted;  
	// check for existence of prior archive before saving
	if ([photosDB count] || ([[NSFileManager defaultManager] fileExistsAtPath:photosArchiveFilePath])) {
		
		[NSKeyedArchiver archiveRootObject:photosDB toFile:photosArchiveFilePath];
		
	} else {
		WPLog(@"No photos in list. there is nothing to save!");
	}
}

#pragma mark Image 

- (CGSize)imageResizeSizeForImageSize:(CGSize)imgSize
{	
	float oWidth = imgSize.width;
	float oHeight = imgSize.height;
	float nWidth = 64;
	float nHeight = 64;
	
	float aspectRatio =  oWidth / oHeight;
	
	if((float)nWidth/nHeight > aspectRatio) {
		nWidth = ceil(nHeight * aspectRatio);	
	} else {
		nHeight = ceil(nWidth / aspectRatio);
	}
	
	return CGSizeMake(nWidth, nHeight);	
}

- (UIImage *)smallImage:(UIImage *)image
{
	CGImageRef imageRef = [image CGImage];	
	
	CGSize imgSize = [image size];
	float oWidth = imgSize.width;
	float oHeight = imgSize.height;
	float nWidth = 64;
	float nHeight = 64;
	
	float aspectRatio =  oWidth / oHeight;
	CGRect drawRect = CGRectZero;

	if(aspectRatio < 1) { //p
		nHeight = ceil(nWidth / aspectRatio);
		drawRect.origin.y -= ((nHeight - nWidth)/2.0);
	} else { //l
		nWidth = ceil(nHeight * aspectRatio);	
		drawRect.origin.x -= ((nWidth-nHeight)/2.0);
	}
	
	CGContextRef bitmap = CGBitmapContextCreate(
												NULL,
												64,
												64,
												CGImageGetBitsPerComponent(imageRef),
												4*64,
												CGImageGetColorSpace(imageRef),
												CGImageGetBitmapInfo(imageRef)
												);	
	
	drawRect.size.width = nWidth;
	drawRect.size.height = nHeight;

	CGContextDrawImage( bitmap, drawRect, imageRef );
	CGImageRef ref = CGBitmapContextCreateImage( bitmap );
	
//	CGImageRef square = CGImageCreateWithImageInRect( ref, drawRect );
	//we are releasing in the called method.
	UIImage *theImage = [[UIImage alloc] initWithCGImage:ref];
	
	CGContextRelease( bitmap );
	CGImageRelease( ref );
//	CGImageRelease( square );
	
	//we are releasing in the called method.
	return theImage;
}

- (NSString *)saveImage:(UIImage *)aImage {
	CFUUIDRef     myUUID;
	CFStringRef   myUUIDString;
	char          strBuffer[256];
	
	myUUID = CFUUIDCreate(kCFAllocatorDefault);
	myUUIDString = CFUUIDCreateString(kCFAllocatorDefault, myUUID);
	
	// This is the safest way to obtain a C string from a CFString.
	CFStringGetCString(myUUIDString, strBuffer, 256, kCFStringEncodingASCII);
	
//	char *prefix = "l";
//	switch ( aImage.imageOrientation )
//	{
//		case UIImageOrientationUp:
//		case UIImageOrientationDown:
//		case UIImageOrientationUpMirrored:
//		case UIImageOrientationDownMirrored:
//			prefix = "p";
//			break;
//	}
	
	CFStringRef outputString = NULL;
	int width = aImage.size.width, height = aImage.size.height;
	if( width < height )
	{
		outputString = CFStringCreateWithFormat(kCFAllocatorDefault,
												NULL,
												CFSTR("p_%d_%d_%s"),
												height, width, strBuffer);		
	}
	else 
	{
		outputString = CFStringCreateWithFormat(kCFAllocatorDefault,
												NULL,
												CFSTR("l_%d_%d_%s"),
												width, height, strBuffer);		
	}

	CFShow(outputString);
	NSString *filePath = [NSString stringWithFormat:@"/%@/%@.jpeg",[self blogDir:currentBlog],(NSString *)outputString];
	NSData *imgData = UIImageJPEGRepresentation( aImage, 0.5 );
	[imgData writeToFile:filePath atomically:YES];
	NSString *returnValue = [NSString stringWithFormat:@"%@.jpeg",outputString];
	
		UIImage * si = [self smallImage:aImage];

	
//	UIImage * rotationImage = [UIImage imageWithData:imgData];
//	rotationImage= [self scaleAndRotateImage:rotationImage];
//
//	UIImage * si = [self smallImage:rotationImage];

	NSData *siData = UIImageJPEGRepresentation( si, 0.8 );
	[si release];
	filePath = [NSString stringWithFormat:@"/%@/t_%@.jpeg",[self blogDir:currentBlog],(NSString *)outputString];
	[siData writeToFile:filePath atomically:YES];

	CFRelease(outputString);
	CFRelease(myUUIDString);
	CFRelease(myUUID);

	return returnValue;
}

- (UIImage *)thumbnailImageNamed:(NSString *)name forBlog:(id)blog {
	UIImage *image = [[UIImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/t_%@",[self blogDir:blog],name]];
	return [image autorelease];
}

- (UIImage *)imageNamed:(NSString *)name forBlog:(id)blog {
	UIImage *image = [[UIImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",[self blogDir:blog],name]];
	return [image autorelease];
}

- (BOOL)deleteImageNamed:(NSString *)name forBlog:(id)blog {
	NSError *error;
	NSString *imgPath = [NSString stringWithFormat:@"%@/%@",[self blogDir:blog], name];
	[[NSFileManager defaultManager] removeItemAtPath:imgPath error:&error];
	imgPath = [NSString stringWithFormat:@"%@/t_%@",[self blogDir:blog], name];
	[[NSFileManager defaultManager] removeItemAtPath:imgPath error:&error];
	if (error)
		return NO;
	return YES;
}

- (BOOL)deleteAllPhotosForCurrentPostBlog
{
	return [self deleteAllPhotosForPost:currentPost forBlog:currentBlog];
}

- (BOOL)deleteAllPhotosForPost:(id)aPost forBlog:(id)aBlog
{
	NSMutableArray *photos = [aPost valueForKey:@"Photos"];
	int i, count = [photos count];
	NSString *curPath = nil;
	
	for( i=count-1; i >=0 ; i-- )
	{
		curPath = [photos objectAtIndex:i];
		[self deleteImageNamed:curPath forBlog:aBlog];
	}
	
	return YES;
}


- (BOOL)deleteAllPhotosForCurrentPageBlog
{
	return [self deleteAllPhotosForPage:currentPage forBlog:currentBlog];
}

- (BOOL)deleteAllPhotosForPage:(id)aPage forBlog:(id)aBlog
{
	NSMutableArray *photos = [aPage valueForKey:@"Photos"];
	int i, count = [photos count];
	NSString *curPath = nil;
	
	for( i=count-1; i >=0 ; i-- )
	{
		curPath = [photos objectAtIndex:i];
		[self deleteImageNamed:curPath forBlog:aBlog];
	}
	
	return YES;
}


#pragma mark Blog

- (NSInteger)countOfBlogs {
	return [blogsList count];
}


- (NSDictionary *)blogAtIndex:(NSUInteger)theIndex {
	
	return [blogsList objectAtIndex:theIndex];

}

- (NSDictionary *) blogForId:(NSString *)aBlogid hostName:(NSString *)hostname{
	
	NSMutableDictionary *aBlog;
	NSEnumerator *blogEnum = [blogsList objectEnumerator];
	
	while (aBlog = [blogEnum nextObject])
	{
		if ([[aBlog valueForKey:@"blogid"] isEqualToString:aBlogid] &&
			[[aBlog valueForKey:@"blog_host_name"] isEqualToString:hostname]) {
			
			return aBlog; 
		}
	}
	
	// return an empty dictionary to signal that blog id was not found
	return [NSDictionary dictionary];
	
}

- (BOOL)doesBlogExists:(NSDictionary *)aBlog{
	NSString *urlstr = [aBlog valueForKey:@"url"]; 
	if ( ![urlstr hasPrefix:@"http"] )
		urlstr = [NSString stringWithFormat:@"http://%@", urlstr];
	NSMutableDictionary *tempBlog;
	NSEnumerator *blogEnum = [blogsList objectEnumerator];
	while (tempBlog = [blogEnum nextObject])
	{
		if ([[tempBlog valueForKey:@"url"] isEqualToString: urlstr] &&
			[[tempBlog valueForKey:@"username"] isEqualToString:[aBlog valueForKey:@"username"]] 
			&& [[tempBlog valueForKey:@"pwd"] isEqualToString:[aBlog valueForKey:@"pwd"]] ) {
			
			return YES; 
		}
	}
	return NO;
}

- (NSString *)defaultTemplateHTMLString
{
	NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
	NSString *fpath = [NSString stringWithFormat:@"%@/defaultPostTemplate.html", resourcePath];
	NSString *str = [NSString stringWithContentsOfFile:fpath];
	return str;
}

- (NSString *)templateHTMLStringForBlog:(id)aBlog isDefaultTemplate:(BOOL *)flag
{
	NSString *fpath = [self templatePathForBlog:currentBlog];
	NSString *str = [NSString stringWithContentsOfFile:fpath encoding:NSUTF8StringEncoding error:NULL];
	if( !str )
	{
		str = [self defaultTemplateHTMLString];
		*flag = YES; 
	}
	else 
	{
		*flag = NO;
	}

	return str;
}

//TODO: remove
- (id)newDraftsBlog 
{	
	NSArray *blogInitValues = [NSArray arrayWithObjects:@"Local Drafts", @"", kDraftsHostName,@"iPhone",
							   @"", kDraftsBlogIdStr, @"Local Drafts", @"",
							   @"",@"",@"",@"", 
							   [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], 
							   [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], @"/xmlrpc.php",@"", @"", nil];	
		
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:blogInitValues forKeys:[self blogFieldNames]];
	
	[dict setObject:@"0" forKey:@"kNextDraftIdStr"];
	return dict;
}

- (void)makeNewBlogCurrent {
	
	self->isLocaDraftsCurrent = NO;
	
	NSArray *blogInitValues = [NSArray arrayWithObjects:@"", @"", @"",@"",
									@"", @"", @"", @"",
									@"",@"",@"",@"", 
								   [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], 
								   [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], @"/xmlrpc.php",@"",@"10 Recent Posts", nil];	
	

	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:blogInitValues forKeys:[self blogFieldNames]];
	[dict setObject:@"0" forKey:kNextDraftIdStr];
	[dict setObject:@"0" forKey:kNextPageDraftIdStr];

	[dict setObject:[NSNumber numberWithInt:0] forKey:kDraftsCount];
	[dict setObject:[NSNumber numberWithInt:0] forKey:kNextPageDraftIdStr];

	[dict setObject:[NSNumber numberWithInt:1] forKey:kResizePhotoSetting];
	// setCurrentBlog will release current reference and make a mutable copy of this one
	[self setCurrentBlog:dict];
	
	// reset the currentBlogIndex to -1 indicating new blog;
	currentBlogIndex = -1;
	
}


- (void)makeLocalDraftsCurrent {
	
	self->isLocaDraftsCurrent = YES;
	
}


- (void)copyBlogAtIndexCurrent:(NSUInteger)theIndex
{
	id cb = [[blogsList objectAtIndex:theIndex] mutableCopy];
	[self setCurrentBlog:cb];
	[cb release];
	
	// save the current index as well
	currentBlogIndex = theIndex;
}

- (void)makeBlogAtIndexCurrent:(NSUInteger)theIndex {
	
	[self setCurrentBlog:[blogsList objectAtIndex:theIndex]];	
	
	// save the current index as well
	currentBlogIndex = theIndex;

	
}

- (void)saveCurrentBlog {
	
	if (isLocaDraftsCurrent) {
		return;
	}
	
	// save it to the current index if set or add it 
	
	if (currentBlogIndex == -1) {
		id cb = [currentBlog mutableCopy];
		[blogsList addObject:cb];
		[cb release];
		
		//re-sort the blogs list to place the new blog at the proper index
		[self sortBlogData];
		[self saveBlogData];
		
		//find the index where the blog was placed
		currentBlogIndex = [self indexForBlogid:[currentBlog valueForKey:@"blogid"] 
									   hostName:[currentBlog valueForKey:@"blog_host_name"]];
		
	} else {
		[blogsList replaceObjectAtIndex:currentBlogIndex withObject:[currentBlog mutableCopy]];
		// not need to re-sort here - we're not allowing change to blog name
	}
}

- (void)removeCurrentBlog
{
	if( [[NSFileManager defaultManager] removeItemAtPath:[self blogDir:currentBlog] error:nil] )
	{
		[blogsList removeObjectAtIndex:currentBlogIndex];
		[self saveBlogData];
		[self resetCurrentBlog];
	}
}

- (void)resetCurrentBlog {
	currentBlog = nil;
	currentBlogIndex = -3;
}

- (NSInteger) indexForBlogid:(NSString *)aBlogid  hostName:(NSString *)hostname {
	
	NSMutableDictionary *aBlog;
	NSEnumerator *blogEnum = [blogsList objectEnumerator];
	int index = 0;
	
	while (aBlog = [blogEnum nextObject])
	{
		if ([[aBlog valueForKey:@"blogid"] isEqualToString:aBlogid] &&
			[[aBlog valueForKey:@"blog_host_name"] isEqualToString:hostname]) {
			
			return index; 
		}
			
		index++;
	}
	
	// signal that blog id was not found
	return -1;
			
}

#pragma mark PostTitle metadata

- (NSArray *)postTitleFieldNames {
	
	if (!postTitleFieldNames) {
		
		self->postTitleFieldNames = [NSArray arrayWithObjects:@"local_status", @"dateCreated", @"blogid",  @"blog_host_name", 
														@"blogName", @"postid", @"title", @"authorid", @"wp_author_display_name", @"status", 
														@"mt_excerpt", @"mt_keywords", @"date_created_gmt", 
														@"newcomments", @"totalcomments",kAsyncPostFlag,nil];
		[postTitleFieldNames retain];
		
	}
	
	return postTitleFieldNames;
}

- (NSDictionary *)postTitleFieldNamesByTag {
	
	if(!postTitleFieldNamesByTag) {
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
		NSNumber *tag15 = [NSNumber numberWithInt:115];				
		
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, 
						 tag9, tag10, tag11, tag12, tag13,tag14,tag15,nil];
		self->postTitleFieldNamesByTag = [NSDictionary dictionaryWithObjects:[self postTitleFieldNames] forKeys:tags];
		
		[postTitleFieldNamesByTag retain];
		
	}
	
	return postTitleFieldNamesByTag;
}

- (NSDictionary *)postTitleFieldTagsByName {
	
	if(!postTitleFieldTagsByName) {
		
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
   		NSNumber *tag15 = [NSNumber numberWithInt:115];

		
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, 
						 tag9, tag10, tag11, tag12, tag13, tag14,tag15, nil];
		self->postTitleFieldTagsByName = [NSDictionary dictionaryWithObjects:tags forKeys:[self postTitleFieldNames]];
		
		[postTitleFieldTagsByName retain];
	}
	
	return postTitleFieldTagsByName;
}

#pragma mark PostTitle Data

- (NSMutableArray *)postTitlesForBlog:(id)aBlog
{
	NSString *postTitlesFilePath = [self pathToPostTitles:aBlog];
	if ([[NSFileManager defaultManager] fileExistsAtPath:postTitlesFilePath]) 
	{

        return [NSMutableArray arrayWithContentsOfFile:postTitlesFilePath];
	}

	return [NSMutableArray array];
}

- (NSMutableArray *)pageTitlesForBlog:(id)aBlog
{
	NSString *pageTitlesFilePath = [self pathToPageTitles:aBlog];
	if ([[NSFileManager defaultManager] fileExistsAtPath:pageTitlesFilePath]) 
	{
        return [NSMutableArray arrayWithContentsOfFile:pageTitlesFilePath];
	}
	
	return [NSMutableArray array];
}

- (NSMutableArray *)commentTitlesForBlog:(id)aBlog
{
	NSString *commentTitlesFilePath = [self pathToCommentTitles:aBlog];
	if ([[NSFileManager defaultManager] fileExistsAtPath:commentTitlesFilePath]) 
	{
		return [NSMutableArray arrayWithContentsOfFile:commentTitlesFilePath];
	}
	
	return [NSMutableArray array];
}

- (NSMutableArray *)commentTitlesForCurrentBlog
{
	return [self commentTitlesForBlog:currentBlog];
}

- (NSInteger)numberOfDrafts
{
	return [draftTitlesList count];
}

- (NSInteger)numberOfPageDrafts
{
	return [pageDraftTitlesList count];
}

- (NSMutableArray *)draftTitlesForBlog:(id)aBlog
{
	NSString *draftTitlesFilePath = [self pathToDraftTitlesForBlog:aBlog];
	if ([[NSFileManager defaultManager] fileExistsAtPath:draftTitlesFilePath]) 
	{
		return [NSMutableArray arrayWithContentsOfFile:draftTitlesFilePath];
	}
	
	return [NSMutableArray array];	
}


- (NSMutableArray *)pageDraftTitlesForBlog:(id)aBlog
{
	NSString *draftTitlesFilePath = [self pathToPageDraftTitlesForBlog:aBlog];
	if ([[NSFileManager defaultManager] fileExistsAtPath:draftTitlesFilePath]) 
	{
		return [NSMutableArray arrayWithContentsOfFile:draftTitlesFilePath];
	}
	
	return [NSMutableArray array];	
}



- (void)loadPageDraftTitlesForBlog:(id)aBlog
{
	[self setPageDraftTitlesList:[self pageDraftTitlesForBlog:aBlog]];
}

- (void)loadPageDraftTitlesForCurrentBlog
{
	[self loadPageDraftTitlesForBlog:currentBlog];
}




- (void)loadDraftTitlesForBlog:(id)aBlog
{
	[self setDraftTitlesList:[self draftTitlesForBlog:aBlog]];
}

- (void)loadDraftTitlesForCurrentBlog
{
	[self loadDraftTitlesForBlog:currentBlog];
}

-(id)draftTitleAtIndex:(NSInteger)anIndex
{
	return [draftTitlesList objectAtIndex:anIndex];
}

-(id)pageDraftTitleAtIndex:(NSInteger)anIndex
{
	return [pageDraftTitlesList objectAtIndex:anIndex];
}

- (BOOL)makeDraftWithIDCurrent:(NSString *)aDraftID
{
	NSArray *draftTitles = [self draftTitlesForBlog:self.currentBlog];
	int index = [[draftTitles valueForKey:@"draftid"] indexOfObject:aDraftID];
	if( index >=0 && index < [draftTitles count] )
	{
		return [self makeDraftAtIndexCurrent:index];
	}
	
	return NO;
}

- (BOOL)makeDraftAtIndexCurrent:(NSInteger)anIndex
{
	NSString *draftPath = [self pathToDraft:[self draftTitleAtIndex:anIndex] forBlog:currentBlog];
	NSMutableDictionary *draft = [NSMutableDictionary dictionaryWithContentsOfFile:draftPath];
	//[draft setValue:[NSDate date] forKey:@"date_created_gmt"];
	[self setCurrentPost:draft];
	currentDraftIndex = anIndex;
	currentPostIndex = -2;
	return YES;
}

- (BOOL)makePageDraftAtIndexCurrent:(NSInteger)anIndex
{
	NSString *draftPath = [self pathToPageDraft:[self pageDraftTitleAtIndex:anIndex] forBlog:currentBlog];
	NSMutableDictionary *draft = [NSMutableDictionary dictionaryWithContentsOfFile:draftPath];
	[self setCurrentPage:draft];
	currentPageDraftIndex = anIndex;
	currentPageIndex = -2;
	return YES;
}


- (BOOL)deleteDraftAtIndex:(NSInteger)anIndex forBlog:(id)aBlog
{
	NSString *draftPath = [self pathToDraft:[self draftTitleAtIndex:anIndex] forBlog:aBlog];
	NSMutableArray *dTitles = [self draftTitlesForBlog:(id)aBlog];
	[dTitles removeObjectAtIndex:anIndex];
	
	[aBlog setValue:[NSNumber numberWithInt:[dTitles count]] forKey:@"kDraftsCount"];
	
	[self deleteAllPhotosForCurrentPostBlog];
	
	[[NSFileManager defaultManager] removeItemAtPath:draftPath error:nil];
	[dTitles writeToFile:[self pathToDraftTitlesForBlog:aBlog] atomically:YES];
	[self saveBlogData];
	return YES;
}



- (BOOL)deletePageDraftAtIndex:(NSInteger)anIndex forBlog:(id)aBlog
{
	NSString *pageDraftPath = [self pathToPageDraft:[self  pageDraftTitleAtIndex:anIndex] forBlog:aBlog];
	NSMutableArray *pageDraftTitles = [self pageDraftTitlesForBlog:(id)aBlog];
	[pageDraftTitles removeObjectAtIndex:anIndex];
	
	[aBlog setValue:[NSNumber numberWithInt:[pageDraftTitles count]] forKey:@"kPageDraftsCount"];
	
	[self deleteAllPhotosForCurrentPageBlog];
	
	[[NSFileManager defaultManager] removeItemAtPath:pageDraftPath error:nil];
	[pageDraftTitles writeToFile:[self pathToPageDraftTitlesForBlog:aBlog] atomically:YES];
	[self saveBlogData];
	return YES;
}





- (void)resetDrafts
{
	currentDraftIndex = -1;
	[self setDraftTitlesList:nil];
}

- (void)resetCurrentDraft
{
	currentDraftIndex = -1;
	[self setCurrentPost:nil];
}

- (void)resetCurrentPageDraft
{
	currentPageDraftIndex = -1;
	[self setCurrentPage:nil];
}


- (id)loadPostTitlesForBlog:(id)aBlog
{
	// set method will make a mutable copy and retain
	[self setPostTitlesList: [self postTitlesForBlog:aBlog]];
	return nil;
	
	//TODO: Remove junk
//	
//	// append blog host to the curr dir path to get the dir at which a blog keeps its posts and drafts
//	NSString *blogHostDir = [currentDirectoryPath stringByAppendingPathComponent:[aBlog objectForKey:@"blog_host_name"]];
//	
////	// append blog id to the curr dir path to get the dir at which a blog keeps its posts and drafts
////	// local drafts are loaded from "localdrafts" dir
////	
//	NSString *blogDir;
////	if (isLocaDraftsCurrent) {
////		blogDir = [blogHostDir stringByAppendingPathComponent:@"localdrafts"];
////	} else {
//		
//		blogDir = [blogHostDir stringByAppendingPathComponent:[aBlog objectForKey:@"blogid"]];
////	}
//	
//	
//	NSString *postTitlesFilePath = [blogDir stringByAppendingPathComponent:@"postTitles.archive"];
//	
//	
//	if ([[NSFileManager defaultManager] fileExistsAtPath:postTitlesFilePath]) {
//		
//		// set method will make a mutable copy and retain
//		[self setPostTitlesList: [NSArray arrayWithContentsOfFile:postTitlesFilePath]];//[NSKeyedUnarchiver unarchiveObjectWithFile:]];
//		
//	} 
//	
//		  [aBlog objectForKey:@"blogName"],	
//		  [aBlog objectForKey:@"blog_host_name"]);	
//	return nil;
}

- (void)loadPostTitlesForCurrentBlog {
	[self loadPostTitlesForBlog:currentBlog];
}

- (void)loadPageTitlesForCurrentBlog {
	[self loadPageTitlesForBlog:currentBlog];
}

- (void)loadCommentTitlesForCurrentBlog {
	[self loadCommentTitlesForBlog:currentBlog];
}

- (id)loadPageTitlesForBlog:(id)aBlog
{
	// set method will make a mutable copy and retain
	[self setPageTitlesList: [self pageTitlesForBlog:aBlog]];
	return nil;
}

- (id)loadCommentTitlesForBlog:(id)aBlog
{
	// set method will make a mutable copy and retain
	[self setCommentTitlesList: [self commentTitlesForBlog:aBlog]];
	return nil;
}

// TODO: we don't need this any more.
-(void)sortPostTitlesList {
	
	if (postTitlesList.count) {
		
		
		// Create a descriptor to sort blog dictionaries by blogName
		NSSortDescriptor *dateCreatedSortDescriptor =  [[NSSortDescriptor alloc] 
														initWithKey:@"date_created_gmt" ascending:YES
														selector:@selector(localizedCaseInsensitiveCompare:)];
		NSArray *sortDescriptors = [NSArray arrayWithObjects:dateCreatedSortDescriptor, nil];
		[postTitlesList sortUsingDescriptors:sortDescriptors];
		[dateCreatedSortDescriptor release];
	}
	
}

- (NSInteger)countOfPostTitles {
	return [postTitlesList count];
}

- (NSInteger)countOfCommentTitles {
	return [commentTitlesList count];
}

- (NSArray *)commentTitles {
	return commentTitlesList;
}

- (NSDictionary *)postTitleAtIndex:(NSUInteger)theIndex {
	
    
    return [postTitlesList objectAtIndex:theIndex];
	
}


- (NSDictionary *)commentTitleAtIndex:(NSUInteger)theIndex {
	
	return [commentTitlesList objectAtIndex:theIndex];
	
}

- (NSInteger) indexOfPostTitle:(id)postTitle inList:(NSArray *)aPostTitlesList {
	
	NSDictionary *aPostTitle;
	NSEnumerator *postTitlesEnum = [aPostTitlesList objectEnumerator];
	
	int i = 0;
	while (aPostTitle = [postTitlesEnum nextObject])
	{
		if ([[aPostTitle valueForKey:@"blogid"] isEqualToString:[postTitle valueForKey:@"blogid"]] &&
			[[aPostTitle valueForKey:@"blog_host_name"]isEqualToString:[postTitle valueForKey:@"blog_host_name"]] &&
			[[aPostTitle valueForKey:@"postid"]isEqualToString:[postTitle valueForKey:@"postid"]]) {
			return i; 
		}
		i++;
	}
	
	// return -1 to signal that postTitle was not found
	return -1;
	
	
}

- (void)resetPostTitlesList {
	[postTitlesList removeAllObjects];
	[self resetCurrentPost];
}

#pragma mark Post metadata

- (NSArray *)postFieldNames {
	
	if (!postFieldNames) {
		// local_status is :
		//  'new' for posts created locally
		//  'edit' for posts that are downloaded and edited locally
		//  'original' for downlaoded posts that have not been edited locally
		// At the time a post is downloaded or created, we add blogid and blog_host_name fields to post dict
		
		self->postFieldNames = [NSArray arrayWithObjects:@"local_status", @"dateCreated", @"userid", 
								@"postid", @"description", @"title", @"permalink", 
								@"slug", @"wp_password", @"authorid", @"status", 
								@"mt_excerpt", @"mt_text_more", @"mt_keywords", 
								@"not_used_allow_comments", @"link_to_comments", @"not_used_allow_pings",@"dateUpdated", 
								@"blogid", @"blog_host_name", @"wp_author_display_name",@"date_created_gmt",kAsyncPostFlag, nil];
		[postFieldNames retain];
		
	}
	
	return postFieldNames;
}


- (NSDictionary *)postFieldNamesByTag {
	
	if(!postFieldNamesByTag) {
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
		NSNumber *tag15 = [NSNumber numberWithInt:115];
		NSNumber *tag16 = [NSNumber numberWithInt:116];
		NSNumber *tag17 = [NSNumber numberWithInt:117];
		NSNumber *tag18 = [NSNumber numberWithInt:118];
		NSNumber *tag19 = [NSNumber numberWithInt:119];
		NSNumber *tag20 = [NSNumber numberWithInt:120];
		NSNumber *tag21 = [NSNumber numberWithInt:121];
		NSNumber *tag22 = [NSNumber numberWithInt:122];

		
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, 
						 tag9, tag10, tag11, tag12, tag13, tag14, tag15, tag16,tag17,tag18, tag19, tag20, tag21,tag22,  nil];
		self->postFieldNamesByTag = [NSDictionary dictionaryWithObjects:[self postFieldNames] forKeys:tags];
		
		[postFieldNamesByTag retain];
		
	}
	
	return postFieldNamesByTag;
}

- (NSDictionary *)postFieldTagsByName {
	
	if(!postFieldTagsByName) {
		
		NSNumber *tag0 = [NSNumber numberWithInt:100];
		NSNumber *tag1 = [NSNumber numberWithInt:101];
		NSNumber *tag2 = [NSNumber numberWithInt:102];
		NSNumber *tag3 = [NSNumber numberWithInt:103];
		NSNumber *tag4 = [NSNumber numberWithInt:104];
		NSNumber *tag5 = [NSNumber numberWithInt:105];
		NSNumber *tag6 = [NSNumber numberWithInt:106];
		NSNumber *tag7 = [NSNumber numberWithInt:107];
		NSNumber *tag8 = [NSNumber numberWithInt:108];
		NSNumber *tag9 = [NSNumber numberWithInt:109];
		NSNumber *tag10 = [NSNumber numberWithInt:110];
		NSNumber *tag11 = [NSNumber numberWithInt:111];
		NSNumber *tag12 = [NSNumber numberWithInt:112];
		NSNumber *tag13 = [NSNumber numberWithInt:113];
		NSNumber *tag14 = [NSNumber numberWithInt:114];
		NSNumber *tag15 = [NSNumber numberWithInt:115];
		NSNumber *tag16 = [NSNumber numberWithInt:116];
		NSNumber *tag17 = [NSNumber numberWithInt:117];
		NSNumber *tag18 = [NSNumber numberWithInt:118];
		NSNumber *tag19 = [NSNumber numberWithInt:119];
		NSNumber *tag20 = [NSNumber numberWithInt:120];
		NSNumber *tag21 = [NSNumber numberWithInt:121];
		
		
		NSArray *tags = [NSArray arrayWithObjects:tag0, tag1, tag2, tag3, tag4, tag5, tag6, tag7, tag8, 
						 tag9, tag10, tag11, tag12, tag13, tag14, tag15, tag16, tag17,tag18, tag19, tag20,tag21, nil];
		self->postFieldTagsByName = [NSDictionary dictionaryWithObjects:tags forKeys:[self postFieldNames]];
		
		[postFieldTagsByName retain];
	}
	
	return postFieldTagsByName;
}

#pragma mark Page

- (BOOL)savePage:(id)aPage
{
	BOOL successFlag = NO;
	NSArray *photos=[currentPage valueForKey:@"Photos"];
	
	if(photos!=NULL)
	{
		if( ![self appendImagesOfCurrentPageToDescription] )
		{
			return successFlag;
		}
	}
	
	if(currentPageIndex == -1 || isLocaDraftsCurrent)
	{
		NSMutableDictionary *pageParams = [NSMutableDictionary dictionary];
		
		NSString *title = [currentPage valueForKey:@"title"];
		title = (title == nil ? @"" : title );
		[pageParams setObject:title forKey:@"title"];
		
		NSString *description = [currentPage valueForKey:@"description"];
		description = (description == nil ? @"" : description );
		[pageParams setObject:description forKey:@"description"];
		
		
		NSString *post_status = [currentPage valueForKey:@"page_status"];	
		if ( !post_status || [post_status isEqualToString:@""] )
			post_status = @"publish";
		[pageParams setObject:post_status forKey:@"page_status"];
		
		//[pageParams setObject:[currentPage valueForKey:@"wp_password"] forKey:@"wp_password"];
		NSArray *args = [NSArray arrayWithObjects:[currentBlog valueForKey:@"blogid"],
						 [currentBlog valueForKey:@"username"],
						 [currentBlog valueForKey:@"pwd"],
						 pageParams,
						 nil ];
		
		//TODO: take url from current page
		XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[currentBlog valueForKey:@"xmlrpc"]]];
		
		[request setMethod:@"wp.newPage" withObjects:args];

		id response = [self executeXMLRPCRequest:request byHandlingError:YES];
		

		[request release];
		
		if( ![response isKindOfClass:[NSError class]] )
			successFlag = YES;

		//if it is a draft and we successfully published then remove from drafts.
		if( isLocaDraftsCurrent && ![response isKindOfClass:[NSError class]] ) {
			NSMutableArray *draftPageTitleList = [self pageDraftTitlesForBlog:currentBlog];
			[draftPageTitleList removeObjectAtIndex:currentPageDraftIndex];
			[draftPageTitleList writeToFile:[self pathToPageDraftTitlesForBlog:currentBlog]  atomically:YES];
			[self setPageDraftTitlesList:draftPageTitleList];
			
			NSString *pagedraftPath = [self pathToPageDraft:currentPost forBlog:currentBlog];
			[[NSFileManager defaultManager] removeItemAtPath:pagedraftPath error:nil];
			
			NSNumber *dc = [currentBlog valueForKey:kPageDraftsCount];
			[currentBlog setValue:[NSNumber numberWithInt:[dc intValue]-1] forKey:kPageDraftsCount];			
			[self saveBlogData];
		}
		[self fectchNewPage:response formBlog:currentBlog];
	}
	else
	{
		NSDate *date = [currentPage valueForKey:@"date_created_gmt"];
		NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
		NSDate *gmtDate = [date addTimeInterval:(secs*-1)];
		[currentPage setObject:gmtDate forKey:@"date_created_gmt"];
		
		NSString *page_status = [currentPage valueForKey:@"page_status"];
		if ( !page_status || [page_status isEqualToString:@""] ) 
			page_status = @"publish";
		[currentPage setObject:page_status forKey:@"page_status"];
		//[currentPage setObject:[currentPage valueForKey:@"wp_password"] forKey:@"wp_password"];
		NSArray *args = [NSArray arrayWithObjects:[currentBlog valueForKey:@"blogid"],[currentPage valueForKey:@"page_id"],
						 [currentBlog valueForKey:@"username"],
						 [currentBlog valueForKey:@"pwd"],
						 currentPage,
						 nil ];
		//TODO: take url from current post
		XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[currentBlog valueForKey:@"xmlrpc"]]];
		[request setMethod:@"wp.editPage" withObjects:args];
		
		id response = [self executeXMLRPCRequest:request byHandlingError:YES];
		[request release];
		
		if( ![response isKindOfClass:[NSError class]] )
		{
			[self fectchNewPage:[currentPage valueForKey:@"page_id"] formBlog:currentBlog];
			successFlag = YES;
		}
	}
	
	return successFlag;
}

- (void)makeNewPageCurrent {
	NSMutableDictionary *dict =[[NSMutableDictionary alloc]init];
	
	NSString *userid = [currentBlog valueForKey:@"userid"];
	userid = userid ? userid:@"";
	[dict setObject:userid forKey:@"userid"];
	
	// load blog fields into currentBlog
	NSString *blogid = [currentBlog valueForKey:@"blogid"];
	blogid = blogid ? blogid:@"";
	
	NSString *pwd = [currentBlog valueForKey:@"pwd"];
	pwd = pwd ? pwd:@"";
	
	NSString *xmlrpc = [currentBlog valueForKey:@"xmlrpc"];
	xmlrpc = xmlrpc ? xmlrpc:@"";
	NSString *blogHost = [currentBlog valueForKey:@"blog_host_name"];
	
	
	/*self->pageFieldNames = [NSArray arrayWithObjects:@"dateCreated", @"userid", 
	 @"pageid", @"description", @"title", @"permalink", 
	 @"wp_password", @"wp_author_id", @"page_status",@"wp_author" 
	 @"mt_allow_comments", @"mt_allow_pings", @"wp_page_order", 
	 @"wp_page_parent_id", @"wp_page_template", @"wp_slug",@"blogid",
	 @"blog_host_name", @"wp_author_display_name",@"date_created_gmt",kAsyncPostFlag, nil];
	 */
	//NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:pageInitValues  forKeys:[self pageFieldNames]];
	
	[dict setObject:blogHost forKey:@"blog_host_name"];
	[dict setObject:blogid forKey:@"blogid"];
	[dict setObject:@"" forKey:@"pageid"];
	[dict setObject:@"" forKey:@"description"];
	[dict setObject:@"" forKey:@"wp_author"];
	[dict setObject:@"" forKey:@"wp_page_order"];
	[dict setObject:@"" forKey:@"wp_page_parent_id"];
	[dict setObject:@"" forKey:@"wp_page_template"];
	[dict setObject:@"" forKey:@"wp_slug"];
	[dict setObject:@"" forKey:@"wp_author_display_name"];
	[dict setObject:@"" forKey:@"permalink"];
	[dict setObject:@"" forKey:@"wp_author_id"];
	[dict setObject:xmlrpc forKey:@"xmlrpc"];
	[dict setObject:[NSDate date] forKey:@"dateCreated"];
	[dict setObject:[NSDate date] forKey:@"date_created_gmt"];
	[dict setObject:@"" forKey:@"title"];
	[dict setObject:@"Local Draft" forKey:@"page_status"];
	[dict setObject:@"" forKey:@"wp_password"];
	[dict setObject:@"" forKey:@"mt_keywords"];
	[dict setObject:[NSNumber numberWithInt:0] forKey:@"mt_allow_comments"];
	[dict setObject:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
	[dict setObject:[NSNumber numberWithInt:0] forKey:@"mt_allow_pings"];
	[dict setObject:@"" forKey:@"mt_keywords"];
	
	[self setCurrentPage:dict];
	currentPageIndex = -1;
	[dict release];
}

- (NSArray *)pageFieldNames {
	
	if (!pageFieldNames) {
		// local_status is :
		//  'new' for posts created locally
		//  'edit' for posts that are downloaded and edited locally
		//  'original' for downlaoded posts that have not been edited locally
		// At the time a post is downloaded or created, we add blogid and blog_host_name fields to post dict
		
		self->pageFieldNames = [NSArray arrayWithObjects:@"dateCreated", @"userid", 
								@"pageid", @"description", @"title", @"permalink", 
								@"wp_password", @"wp_author_id", @"page_status",@"wp_author" 
								@"mt_allow_comments", @"mt_allow_pings", @"wp_page_order", 
								@"wp_page_parent_id", @"wp_page_template", @"wp_slug",@"blogid",
								@"blog_host_name", @"wp_author_display_name",@"date_created_gmt",kAsyncPostFlag, nil];
		[pageFieldNames retain];
		
	}
	
	return pageFieldNames;
}

- (BOOL) syncPagesForBlog:(id)blog {

	[blog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	
	
	
	//  ------------------------- invoke metaWeblog.getRecentPosts
	XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
	[postsReq setMethod:@"wp.getPages" 
			withObjects:[NSArray arrayWithObjects:blogid,username, pwd, nil]];
	
	id response = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
	[postsReq release];
	// TODO:
	// Check for fault
	// check for nil or empty response
	// provide meaningful messge to user
	if ((!response) || !([response isKindOfClass:[NSArray class]]) ) {
 		[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//		[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
		return NO;
	}
	NSMutableArray *pagesList = [NSMutableArray arrayWithArray:response];
	
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	
	NSMutableArray *pageTitlesArray = [NSMutableArray array];
	
	for ( NSDictionary *page in pagesList ) {
		// add blogid and blog_host_name to post
		NSMutableDictionary *updatedPage = [NSMutableDictionary dictionaryWithDictionary:page];
		
		NSDate* pageGMTDate=[updatedPage valueForKey:@"date_created_gmt"];
		NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:pageGMTDate];
		NSDate *currentDate = [pageGMTDate addTimeInterval:(secs*+1)];
		[updatedPage setValue:currentDate forKey:@"date_created_gmt"];
		
		
		[updatedPage setValue:[blog valueForKey:@"blogid"] forKey:@"blogid"];
		[updatedPage setValue:[blog valueForKey:@"blog_host_name"] forKey:@"blog_host_name"];
		
		NSString *path = [self pageFilePath:updatedPage forBlog:blog];
		
		[defaultFileManager removeItemAtPath:path error:nil];
		[updatedPage writeToFile:path atomically:YES];
		
		[pageTitlesArray addObject:[self pageTitleForPage:updatedPage]];
	}
	
	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[pageTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	[blog setObject:[NSNumber numberWithInt:[pageTitlesArray count]] forKey:@"totalpages"];
	[blog setObject:[NSNumber numberWithInt:1] forKey:@"newpages"];

	NSString *pathToCommentTitles = [self pathToPageTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	

	[pageTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
	[self setPageTitlesList:pageTitlesArray];
	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}
- (NSMutableDictionary *) pageTitleForPage:(NSDictionary *)aPage
{
	NSMutableDictionary *pageTitle = [NSMutableDictionary dictionary];
	
	NSString *blogid = [aPage valueForKey:@"blogid"];
	[pageTitle setObject:(blogid?blogid:@"") forKey:@"blogid"];
	
	NSString *blogHost = [aPage valueForKey:@"blog_host_name"];
	[pageTitle setObject:(blogHost?blogHost:@"") forKey:@"blog_host_name"];
	
	NSString *blogName = [[self blogForId:blogid hostName:blogHost] valueForKey:@"blogName"];
	[pageTitle setObject:(blogName?blogName:@"") forKey:@"blogName"];
	
	
	NSString *pageid = [aPage valueForKey:@"page_id"];
	[pageTitle setObject:(pageid?pageid:@"") forKey:@"page_id"];
	
	NSString *author = [aPage valueForKey:@"wp_author"];
	[pageTitle setObject:(author?author:@"") forKey:@"author"];
	
	NSString *status = [aPage valueForKey:@"page_status"];
	[pageTitle setObject:(status?status:@"") forKey:@"status"];
	
	NSString *pagetitle = [aPage valueForKey:@"title"];
	[pageTitle setObject:(pagetitle?pagetitle:@"") forKey:@"title"];
	
	NSString *dateCreated = [aPage valueForKey:@"date_created_gmt"];
	[pageTitle setObject:(dateCreated?dateCreated:@"") forKey:@"date_created_gmt"];
	
	NSString *content = [aPage valueForKey:@"description"];
	[pageTitle setObject:(content?content:@"") forKey:@"content"];
	
	return pageTitle;	
}

- (NSInteger)countOfPageTitles
{
	return [pageTitlesList count]+1;
}
- (NSDictionary *)pageTitleAtIndex:(NSUInteger)theIndex
{
	return [pageTitlesList objectAtIndex:theIndex];
}
- (void)makePageAtIndexCurrent:(NSUInteger)theIndex {
	

	NSString *pathToPage = [self pageFilePath:[self pageTitleAtIndex:theIndex] forBlog:currentBlog];
	[self setCurrentPage:[NSMutableDictionary dictionaryWithContentsOfFile:pathToPage]];	
	
	// save the current index as well
	currentPageIndex = theIndex;
	currentPageDraftIndex=-1;
//	isPageLocalDraftsCurrent=NO;
	isLocaDraftsCurrent=NO;
}
#pragma mark Post
- (void)saveCurrentPostAsDraftWithAsyncPostFlag
{	
	NSMutableArray *draftTitles = [self draftTitlesForBlog:currentBlog];
	[draftTitles removeObjectAtIndex:currentDraftIndex];
	[draftTitles writeToFile:[self pathToDraftTitlesForBlog:currentBlog]  atomically:YES];
	[currentBlog setObject:[NSNumber numberWithInt:[draftTitles count]] forKey:kDraftsCount];
	[self saveBlogData];
	[self setDraftTitlesList:draftTitles];
	
	NSString *pathToPost = [self pathToDraft:currentPost forBlog:currentBlog];
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	if([defaultFileManager fileExistsAtPath:pathToPost])
		[defaultFileManager removeItemAtPath:pathToPost error:nil];
	
	[self setCurrentUnsavedDraft:currentPost];
	[[NSNotificationCenter defaultCenter]postNotificationName:@"DraftsUpdated" object:nil];
}

- (NSString *)savePostsFileWithAsynPostFlag:(NSMutableDictionary *)postDict{
    BlogDataManager *dm = [BlogDataManager sharedDataManager];
    [postDict setValue:[NSNumber numberWithInt:1] forKey:kAsyncPostFlag];
    NSDictionary *blogDict=[dm currentBlog];
    NSMutableDictionary *postTitleDict=[[NSMutableDictionary alloc]init];
    [postTitleDict setValue:[NSNumber numberWithInt:1] forKey:kAsyncPostFlag]; 
    [postTitleDict setValue:[blogDict valueForKey:@"blogid"] forKey:@"blogid"]; 
    [postTitleDict setValue:[blogDict valueForKey:@"blog_host_name"] forKey:@"blog_host_name"]; 
    [postTitleDict setValue:@"Original" forKey:@"local_status"]; 
    [postTitleDict setValue:[blogDict valueForKey:@"blogName"] forKey:@"blogName"]; 
    [postTitleDict setValue:[postDict valueForKey:@"date_created_gmt"] forKey:@"date_created_gmt"];
    [postTitleDict setValue:[postDict valueForKey:@"mt_excerpt"] forKey:@"mt_excerpt"];  
    [postTitleDict setValue:[postDict valueForKey:@"mt_keywords"] forKey:@"mt_keywords"];  
    [postTitleDict setValue:[postDict valueForKey:@"post_status"] forKey:@"post_status"];
    NSString *postId=[postDict valueForKey:@"postid"];
    if(postId==nil ||[postId isEqual:@""]){  
        postId=[NSString stringWithFormat:@"n%d",[dm unsavedPostsCount]];
        [dm setUnsavedPostsCount:[dm unsavedPostsCount]+1];
     }
  
    [postDict setValue:postId forKey:@"postid"];
    [postTitleDict setValue:postId forKey:@"postid"];  
    
    [postTitleDict setValue:[postDict valueForKey:@"title"] forKey:@"title"];  
    [postTitleDict setValue:[postDict valueForKey:@"wp_author_display_name"] forKey:@"wp_author_display_name"];  
    [postTitleDict setValue:@"" forKey:@"wp_authorid"];  
    NSMutableArray *newPostTitlesList = [NSMutableArray arrayWithContentsOfFile:[self pathToPostTitles:[dm currentBlog]]];
	
	int index = [[newPostTitlesList valueForKey:@"postid"] indexOfObject:postId];
	if( index >= 0 && index < [newPostTitlesList count] )
	{
		[newPostTitlesList removeObjectAtIndex:index];
	}
    [newPostTitlesList addObject:postTitleDict];
    NSSortDescriptor *dateCreatedSortDescriptor =  [[NSSortDescriptor alloc] 
                                                        initWithKey:@"date_created_gmt" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:dateCreatedSortDescriptor, nil];
    [newPostTitlesList sortUsingDescriptors:sortDescriptors];
    [dateCreatedSortDescriptor release];
      
    //[postDict writeToFile:[dm pathToPost:postDict forBlog:[dm currentBlog]] atomically:YES];
    [postTitleDict release]; 
	[newPostTitlesList writeToFile:[self pathToPostTitles:[self currentBlog]]  atomically:YES];
    return postId;
}

- (NSInteger)countOfPosts {
	return 0;
}

- (NSDictionary *)postAtIndex:(NSUInteger)theIndex {
	return nil;
}

- (NSDictionary *)postForId:(NSString *)postid {
	return nil;
}

- (NSUInteger)indexForPostid:(NSString *)postid {
	return -1;
}

- (NSDictionary *)postTitleForId:(NSString *)postTitleid {
	return nil;
}



- (NSUInteger)indexForPostTitleId:(NSString *)postTitleid {
	return -1;
}

// this is a wrapper method which get called in a back ground thread.
// here we need to get the posts first and then we need to generate template.
// these two should not run in parallel, other wise the generate template will create some dummy templates, categories which may get downloaded when we  syncPostsForBlog:
// so these two should run in sequence. this is one way of doing it.
- (BOOL)wrapperForSyncPostsAndGetTemplateForBlog:(id)aBlog
{
	NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
	[aBlog retain];

	[self syncPostsForBlog:aBlog];
	[self generateTemplateForBlog:aBlog];

	if ( [[currentBlog valueForKey:kSupportsPagesAndComments] boolValue] ) {
		[self syncCommentsForBlog:aBlog];
		[self syncPagesForBlog:aBlog];
	}	

	//Has been commented to avoid Empty Blog Creation.
	//	[aBlog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	//	[self saveCurrentBlog];
	
	[self performSelectorOnMainThread:@selector(postBlogsRefreshNotificationInMainThread:) withObject:aBlog waitUntilDone:YES];

	[aBlog release];
	[ap release];
	
	return YES;
}

//TODO: preview based on template.
- (void)generateTemplateForBlog:(id)aBlog
{
	// skip template generation until !$title$! bug can be fixed
	return;
	
	NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
	[aBlog retain];
	
	NSDictionary *catParms = [NSMutableDictionary dictionaryWithCapacity:4];
	[catParms setValue:@"!$categories$!" forKey:@"name"];
	[catParms setValue:@"!$categories$!" forKey:@"description"];
	
	NSArray *catargs = [NSArray arrayWithObjects:[aBlog valueForKey:@"blogid"],
					 [aBlog valueForKey:@"username"],
					 [aBlog valueForKey:@"pwd"],
					 catParms,
					 nil
					 ];
	
	XMLRPCRequest *catRequest = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
	[catRequest setMethod:@"wp.newCategory" withObjects:catargs];
	id catResponse = [self executeXMLRPCRequest:catRequest byHandlingError:NO];
	[catRequest release]; 
	if( [catResponse isKindOfClass:[NSError class]] )
	{
		catResponse = nil;
	}
	
	
	NSMutableDictionary *postParams = [NSMutableDictionary dictionary];
	
	[postParams setObject:@"!$title$!" forKey:@"title"];
	[postParams setObject:@"!$mt_keywords$!" forKey:@"mt_keywords"];
	[postParams setObject:@"!$text$!" forKey:@"description"];
	NSArray *cats = [NSArray arrayWithObjects:@"!$categories$!",nil];
	[postParams setObject:cats forKey:@"categories"];

	[postParams setObject:@"publish" forKey:@"post_status"];
	
	NSArray *args = [NSArray arrayWithObjects:[aBlog valueForKey:@"blogid"],
					 [aBlog valueForKey:@"username"],
					 [aBlog valueForKey:@"pwd"],
					 postParams,
					 nil
					 ];
	
	//TODO: take url from current post
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[currentBlog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"metaWeblog.newPost" withObjects:args];
	
	id postid = [self executeXMLRPCRequest:request byHandlingError:NO];
	[request release];
	
	if( ![postid isKindOfClass:[NSError class]] )
	{
		args = [NSArray arrayWithObjects:
				postid,
				[aBlog valueForKey:@"username"],
				[aBlog valueForKey:@"pwd"],nil];
		
		request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
		[request setMethod:@"metaWeblog.getPost" withObjects:args];
		
		id post = [self executeXMLRPCRequest:request byHandlingError:NO];
		[request release];
		

		if( ![post isKindOfClass:[NSError class]] )
		{
			NSString *fpath = [self templatePathForBlog:aBlog];
			NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:[post valueForKey:@"link"]]
													  cachePolicy:NSURLRequestUseProtocolCachePolicy							  
												  timeoutInterval:60.0];			
			NSData *data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:NULL error:NULL];
			if( [data length] )
			{
				//NSString *str = [NSString stringWithUTF8String:[data bytes]];
				NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
				if(!str || [str rangeOfString:@"!$text$!"].location == NSNotFound ) {
				} else {
					[data writeToFile:fpath atomically:YES];
				}
			}
		}
		
		NSString *bloggerAPIKey = @"ABCDEF012345";
		args = [NSArray arrayWithObjects:
				bloggerAPIKey,
				postid,
				[aBlog valueForKey:@"username"],
				[aBlog valueForKey:@"pwd"],nil];
		
		request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
		[request setMethod:@"metaWeblog.deletePost" withObjects:args];
		[self executeXMLRPCRequest:request byHandlingError:NO];

		[request release];
		
	}

	//delete cat
	if( catResponse )
	{
		NSArray *catargs = [NSArray arrayWithObjects:[aBlog valueForKey:@"blogid"],
						 [aBlog valueForKey:@"username"],
						 [aBlog valueForKey:@"pwd"],
						 catResponse,
						 nil
						 ];
		
		XMLRPCRequest *catRequest = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
		[catRequest setMethod:@"wp.deleteCategory" withObjects:catargs];
		id catResponse = [self executeXMLRPCRequest:catRequest byHandlingError:NO];
		[catRequest release]; 
		if( [catResponse isKindOfClass:[NSError class]] )
		{
			catResponse = nil;
		}		
	}
	
	[aBlog release];
	[ap release];
}

- (void)makeNewPostCurrent {
	
	// Assign:
	// post_type = "post"
	// dateCreated = today
	// userid - assigned from current blog (which needs to be set at the right times)
	// author id = userid 
	
	// Edit
	// postid -  TO-DO need temporary post id for local draft, replaced with server assigned id at publish
	// description - TO_DO the content; needs to be well formed when user hits done on keyboard.
	// title - TO-DO warn if empty; needs to be well formed when user hits done on keyboard.
	// mt_excerpt
	// mt_keywords
	// categories
	// password - have the option to show the password; 
	//   TO-DO store password with simple encryption
	// status : chooser from getAvailableStatuses (draft, pending, private, publish
	// - TO-DO clarify how this is used in mw.newPost and mw.EditPost
	// mt_text_more
	// not_used_allow_comments
	// link_to_comments
	// not_used_allow_pings
				// not_used_allow_pings
	
	// Wordpress Custom Fields - TO-DO
	
	
	NSString *userid = [currentBlog valueForKey:@"userid"];
	userid = userid ? userid:@"";
	
	// load blog fields into currentBlog
	NSString *blogid = [currentBlog valueForKey:@"blogid"];
	blogid = blogid ? blogid:@"";
		
	NSString *pwd = [currentBlog valueForKey:@"pwd"];
	pwd = pwd ? pwd:@"";
	
	NSString *xmlrpc = [currentBlog valueForKey:@"xmlrpc"];
	xmlrpc = xmlrpc ? xmlrpc:@"";
	NSString *blogHost = [currentBlog valueForKey:@"blog_host_name"];
	
	NSCalendar *cal = [NSCalendar currentCalendar];
	
	NSDateComponents *comps = [cal components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit
																	 fromDate:[NSDate date]];
	//	[comps setYear:[year integerValue]];
	//	[comps setMonth:[month integerValue]];
	//	[comps setDay:[day integerValue]];
	//	[comps setHour:[hr integerValue]];
	//	[comps setMinute:[mn integerValue]];
	//	[comps setSecond:[sec	integerValue]];
	
	NSString *month = [NSString stringWithFormat:@"%d",[comps month]];
	if ([month length] == 1)
		month = [NSString stringWithFormat:@"0%@",month];
	
	NSString *day = [NSString stringWithFormat:@"%d",[comps day]];
	if ([day length] == 1)
		day = [NSString stringWithFormat:@"0%@",day];
	NSString *hour = [NSString stringWithFormat:@"%d",[comps hour]];
	if ([hour length] == 1)
		hour = [NSString stringWithFormat:@"0%@",hour];
	NSString *minute = [NSString stringWithFormat:@"%d",[comps minute]];
	if ([minute length] == 1)
		minute = [NSString stringWithFormat:@"0%@",minute];
	NSString *second = [NSString stringWithFormat:@"%d",[comps second]];
	if ([second length] == 1)
		second = [NSString stringWithFormat:@"0%@",second];
	
	NSString *now =  [NSString stringWithFormat:@"%d%@%@T%@:%@:%@", [comps year]	,month	,day		,hour	,minute,second];

	//[[NSCalendarDate date] descriptionWithCalendarFormat:@"%Y%m%dT%H:%M:%S"];
	//												  timeZone:nil locale:nil];
	// TO_DO translate "draft" to "Draft" using the list of supported statuses
	//NSSTring *status = [[BlogDataManager sharedDataManager] blogPostStatusList] valueForKey:@"draft"]
	
//	
//	self->postFieldNames = [NSArray arrayWithObjects:@"local_status", @"dateCreated", @"userid", 
//							@"postid", @"description", @"title", @"permalink", 
//							@"slug", @"wp_password", @"authorid", @"status", 
//							@"mt_excerpt", @"mt_text_more", @"mt_keywords", 
//							@"not_used_allow_comments", @"link_to_comments", @"not_used_allow_pings",@"dateUpdated", 
//							@"blogid", @"blog_host_name", @"wp_author_display_name",@"date_created_gmt", nil];
	
	
	NSArray *postInitValues = 	[NSArray arrayWithObjects:@"post", now, userid, 
								 @"", @"", @"", @"", 
								 @"", @"", @"", @"draft", 
								 @"", @"", @"", 
								 @"", @"", @"", @"", 
								 blogid, blogHost, @"", now,@"",
								 nil];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:postInitValues  forKeys:[self postFieldNames]];
	
	[dict setObject:xmlrpc forKey:@"xmlrpc"];

	//TODO: How to handle localization here.
	NSMutableArray *cats = nil;
	//int index = [[[currentBlog valueForKey:@"categories"] valueForKey:@"categoryName"] indexOfObject:@"Uncategorized"];
	//if( index == -1 )
		cats = [NSMutableArray array];
	//else 
	//	cats = [NSMutableArray arrayWithObject:@"Uncategorized"];
	[dict setObject:cats forKey:@"categories"];

	[dict setObject:@"" forKey:@"title"];
	[dict setObject:@"Local Draft" forKey:@"post_status"];
	[dict setObject:@"Local Draft" forKey:@"post_status_description"];

	[dict setObject:[NSDate date] forKey:@"date_created_gmt"];
	[dict setObject:[NSNumber numberWithBool:0] forKey:@"isLocalDraft"];
	[dict setObject:@"" forKey:@"wp_password"];
	[dict setObject:@"" forKey:@"mt_keywords"];
	[dict setObject:[NSNumber numberWithInt:0] forKey:@"not_used_allow_pings"];
	[dict setObject:@"" forKey:@"mt_excerpt"];
    [dict setObject:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
	[dict setObject:[NSNumber numberWithInt:0] forKey:@"not_used_allow_comments"];
	[dict setObject:@"" forKey:@"mt_keywords"];
	
	NSNumber *value = [currentBlog valueForKey:kResizePhotoSetting];
	if ( !value ) {
		value = [NSNumber numberWithInt:1];
	}
	[dict setObject:value forKey:kResizePhotoSetting];
    
	// setCurrentPost will release current reference and make a mutable copy of this one
	[self setCurrentPost:dict];
 	
	// reset the currentPostIndex to nil;
	currentPostIndex = -1;
	
}

- (BOOL)makePostWithPostIDCurrent:(NSString *)postID
{	
	int index = [[postTitlesList valueForKey:@"postid"] indexOfObject:postID];
	if( index >= 0 && index < [postTitlesList count] )
	{
		[self makePostAtIndexCurrent:index];
		return YES;
	}
	return NO;
}

- (void)makePostAtIndexCurrent:(NSUInteger)theIndex {
	NSString *pathToPost = [self pathToPost:[self postTitleAtIndex:theIndex] forBlog:currentBlog];
	[self setCurrentPost:[NSMutableDictionary dictionaryWithContentsOfFile:pathToPost]];	
	
	// save the current index as well
	currentPostIndex = theIndex;
	isLocaDraftsCurrent = NO;
	currentDraftIndex = -1;
}

- (int)draftExistsForPostTitle:(id)aPostTitle inDraftsPostTitles:(NSArray *)somePostTitles 
{
	int i, count = [somePostTitles count];
	for ( i=0; i<count ; i++)
	{
		id postTitle = [somePostTitles objectAtIndex:i];
		if ([[aPostTitle valueForKey:@"blogid"] isEqualToString:[postTitle valueForKey:@"blogid"]] &&
			[[aPostTitle valueForKey:@"blog_host_name"]isEqualToString:[postTitle valueForKey:@"blog_host_name"]] &&
			[[aPostTitle valueForKey:@"postid"]isEqualToString:[postTitle valueForKey:@"original_postid"]]) {
				return i;
			}
 	}

	return -1;
}


- (id)autoSavedPostForCurrentBlog
{
	return [NSMutableDictionary dictionaryWithContentsOfFile:[self autoSavePathForTheCurrentBlog]];
}

- (BOOL)makeAutoSavedPostCurrentForCurrentBlog
{
	NSMutableDictionary *post = [self autoSavedPostForCurrentBlog];
	if( !post || [post count] == 0 )
		return NO;
	
	NSString *draftID = [post valueForKey:@"draftid"];
	if( draftID )
	{
		[self loadDraftTitlesForBlog:currentBlog];
		int index = [[draftTitlesList valueForKey:@"draftid"] indexOfObject:draftID];
		if( index >= 0 && index < [draftTitlesList count] )
		{
			currentDraftIndex = index;
			currentPostIndex = -2;
		}
		else {
			return NO;
		}
	}	
	else 
	{
		NSString *postID = [post valueForKey:@"postid"];
		if( postID && [postID length] > 0 )
		{
			int index = [[postTitlesList valueForKey:@"postid"] indexOfObject:postID];
			if( index >= 0 && index < [postTitlesList count] )
				currentPostIndex = index;
			else {
				return NO;
			}
		}		
		else
		{
			//new post
			currentPostIndex = -1;
			currentDraftIndex = -1;
		}
	}
	
	[self setCurrentPost:post];
	
	return YES;
}

- (BOOL)autoSaveCurrentPost
{
	return [currentPost writeToFile:[self autoSavePathForTheCurrentBlog] atomically:YES];
}

-(void)saveCurrentPageAsDraft
{	
	
//	//we can't save existing post as draft.
//	if(currentPageIndex != -1 )
//	{
//		return;
//	}
	
	NSMutableArray *draftTitles = [self pageDraftTitlesForBlog:currentBlog];
	
	NSMutableDictionary *pageTitle = [self pageTitleForPage:currentPage];
	//[pageTitle setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
	
	if( !isLocaDraftsCurrent)
	{
		[draftTitles insertObject:pageTitle atIndex:0];
		
		NSString *nextDraftID = [[[currentBlog valueForKey:@"kNextPageDraftIdStr"] retain] autorelease];
		[currentBlog setObject:[[NSNumber numberWithInt:[nextDraftID intValue]+1] stringValue] forKey:@"kNextPageDraftIdStr"];
		NSNumber *draftsCount = [currentBlog valueForKey:kPageDraftsCount];
		[currentBlog setObject:[NSNumber numberWithInt:[draftsCount intValue]+1] forKey:kPageDraftsCount];
		[self saveBlogData];
		
		[currentPage setObject:nextDraftID forKey:@"pageDraftid"];

		[pageTitle setObject:nextDraftID forKey:@"pageDraftid"];
		
		[draftTitles writeToFile:[self pathToPageDraftTitlesForBlog:currentBlog]  atomically:YES];
		NSString *pathToDraft = [self pathToPageDraft:currentPage forBlog:currentBlog];
		[currentPage writeToFile:pathToDraft atomically:YES];
	}
	else
	{
		[pageTitle setObject:[currentPage valueForKey:@"pageDraftid"] forKey:@"pageDraftid"];
		
		[draftTitles replaceObjectAtIndex:currentPageDraftIndex withObject:pageTitle];
		[draftTitles writeToFile:[self pathToPageDraftTitlesForBlog:currentBlog]  atomically:YES];
		
		[pageDraftTitlesList replaceObjectAtIndex:currentPageDraftIndex withObject:pageTitle];
		
		NSString *pathToPage = [self pathToPageDraft:currentPage forBlog:currentBlog];
		[currentPage writeToFile:pathToPage atomically:YES];	
	}
	
	[self resetCurrentPage];
	[self resetCurrentPageDraft];
	
}





- (void)saveCurrentPostAsDraft
{	
	//we can't save existing post as draft.
	if( !isLocaDraftsCurrent && currentPostIndex != -1 )
	{
		return;
	}

	NSMutableArray *draftTitles = [self draftTitlesForBlog:currentBlog];

	NSMutableDictionary *postTitle = [self postTitleForPost:currentPost];
	[postTitle setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
	[currentPost setObject:[NSNumber numberWithBool:1] forKey:@"isLocalDraft"];

	if (currentPostIndex == -1) 
	{
		[draftTitles insertObject:postTitle atIndex:0];
		
		NSString *nextDraftID = [[[currentBlog valueForKey:@"kNextDraftIdStr"] retain] autorelease];
		[currentBlog setObject:[[NSNumber numberWithInt:[nextDraftID intValue]+1] stringValue] forKey:@"kNextDraftIdStr"];
		NSNumber *draftsCount = [currentBlog valueForKey:kDraftsCount];
		[currentBlog setObject:[NSNumber numberWithInt:[draftsCount intValue]+1] forKey:kDraftsCount];
		[self saveBlogData];
		
		[currentPost setObject:nextDraftID forKey:@"draftid"];
		[postTitle setObject:nextDraftID forKey:@"draftid"];
		
		[draftTitles writeToFile:[self pathToDraftTitlesForBlog:currentBlog]  atomically:YES];
		NSString *pathToDraft = [self pathToDraft:currentPost forBlog:currentBlog];
		[currentPost writeToFile:pathToDraft atomically:YES];
	}
	else
	{
		[postTitle setObject:[currentPost valueForKey:@"draftid"] forKey:@"draftid"];

		[draftTitles replaceObjectAtIndex:currentDraftIndex withObject:postTitle];
		[draftTitles writeToFile:[self pathToDraftTitlesForBlog:currentBlog]  atomically:YES];
		
		[draftTitlesList replaceObjectAtIndex:currentDraftIndex withObject:postTitle];
		
		NSString *pathToPost = [self pathToDraft:currentPost forBlog:currentBlog];
		[currentPost writeToFile:pathToPost atomically:YES];	
	}
	
	[self resetCurrentPost];
	[self resetCurrentDraft];
}

- (id)fectchNewPost:(NSString *)postid formBlog:(id)aBlog
{
	NSArray *args = [NSArray arrayWithObjects:postid,
					 [aBlog valueForKey:@"username"],
					 [aBlog valueForKey:@"pwd"],nil];
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"metaWeblog.getPost" withObjects:args];
	
	id post = [self executeXMLRPCRequest:request byHandlingError:YES];
	NSDate* postGMTDate=[post valueForKey:@"date_created_gmt"];
	NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:postGMTDate];
	NSDate *currentDate = [postGMTDate addTimeInterval:(secs*+1)];
	[post setValue:currentDate forKey:@"date_created_gmt"];
	
	[request release];
	if( [post isKindOfClass:[NSError class]] )
	{
		return nil;
	}
	
	[post setValue:[aBlog valueForKey:@"blogid"] forKey:@"blogid"];
	[post setValue:[aBlog valueForKey:@"blog_host_name"] forKey:@"blog_host_name"];
	[post setValue:@"original" forKey:@"local_status"];
	id posttile = [self postTitleForPost:post];
    [posttile setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
	NSMutableArray *newPostTitlesList = [NSMutableArray arrayWithContentsOfFile:[self pathToPostTitles:aBlog]];
	
	int index = [[newPostTitlesList valueForKey:@"postid"] indexOfObject:postid];
	if( index >= 0 && index < [newPostTitlesList count] )
	{
		[newPostTitlesList removeObjectAtIndex:index];
	}
	[newPostTitlesList addObject:posttile];
	
	NSSortDescriptor *dateCreatedSortDescriptor =  [[NSSortDescriptor alloc] 
													initWithKey:@"date_created_gmt" ascending:NO];
	NSArray *sortDescriptors = [NSArray arrayWithObjects:dateCreatedSortDescriptor, nil];
	[newPostTitlesList sortUsingDescriptors:sortDescriptors];
	[dateCreatedSortDescriptor release];
	
	if( !( index >= 0 && index < [newPostTitlesList count] ) ) //not existing post, new post
	{
		[aBlog setObject:[NSNumber numberWithInt:[newPostTitlesList count]] forKey:@"totalposts"];
		[aBlog setObject:[NSNumber numberWithInt:1] forKey:@"newposts"];
	}

    [post setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
    [post writeToFile:[self pathToPost:post forBlog:aBlog] atomically:YES]; ;
	[newPostTitlesList writeToFile:[self pathToPostTitles:aBlog]  atomically:YES];
	
	return post;
}


- (id)fectchNewPage:(NSString *)pageid formBlog:(id)aBlog
{
	NSArray *args = [NSArray arrayWithObjects:
					 [currentBlog valueForKey:@"blogid"],pageid,
					 [aBlog valueForKey:@"username"],
					 [aBlog valueForKey:@"pwd"],nil];
	
	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"wp.getPage" withObjects:args];
	
	id page = [self executeXMLRPCRequest:request byHandlingError:YES];
	NSDate* pageGMTDate=[page valueForKey:@"date_created_gmt"];
	NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:pageGMTDate];
	NSDate *currentDate = [pageGMTDate addTimeInterval:(secs*+1)];
	[page setValue:currentDate forKey:@"date_created_gmt"];
	[request release];
	if( [page isKindOfClass:[NSError class]] )
	{
		return nil;
	}
	
	[page setValue:[aBlog valueForKey:@"blogid"] forKey:@"blogid"];
	[page setValue:[aBlog valueForKey:@"blog_host_name"] forKey:@"blog_host_name"];

	NSMutableArray *newPageTitlesList = [NSMutableArray arrayWithContentsOfFile:[self pathToPageTitles:aBlog]];
	
	int index = [[newPageTitlesList valueForKey:@"page_id"] indexOfObject:[page valueForKey:@"page_id"]];
	if( index >= 0 && index < [newPageTitlesList count] )
	{
		[newPageTitlesList removeObjectAtIndex:index];
	}
	[newPageTitlesList addObject:page];
	
	NSSortDescriptor *dateCreatedSortDescriptor =  [[NSSortDescriptor alloc] 
													initWithKey:@"date_created_gmt" ascending:NO];
	NSArray *sortDescriptors = [NSArray arrayWithObjects:dateCreatedSortDescriptor, nil];
	[newPageTitlesList sortUsingDescriptors:sortDescriptors];
	[dateCreatedSortDescriptor release];
	
	if( !( index >= 0 && index < [newPageTitlesList count] ) ) //not existing post, new post
	{
		[aBlog setObject:[NSNumber numberWithInt:[newPageTitlesList count]] forKey:@"totalpages"];
		[aBlog setObject:[NSNumber numberWithInt:1] forKey:@"newpages"];
	}
	
   // [page setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
    [page writeToFile:[self pageFilePath:page forBlog:aBlog] atomically:YES]; ;
	[newPageTitlesList writeToFile:[self pathToPageTitles:aBlog]  atomically:YES];
	
	return page;
}

- (void)updatePostsTitlesFileAfterPostSaved:(NSMutableDictionary *)dict{

    NSString *savedPostId=[dict valueForKey:@"savedPostId"];
  //  NSString *originalPostId=[dict valueForKey:@"originalPostId"];
     
    NSString *postTitlesPath = [self pathToPostTitles:[self currentBlog]];
    NSMutableArray *postsArray=[NSMutableArray arrayWithContentsOfFile:postTitlesPath];
    int postsCount=[postsArray count];
    for(int i=0;i<postsCount;i++)
    {
		NSMutableDictionary *postDict=[postsArray objectAtIndex:i];
        if([[postDict valueForKey:@"postid"] isEqualToString:savedPostId]){
			if([savedPostId	hasPrefix:@"n"])
				 [postsArray removeObjectAtIndex:i];
			else
				[postDict setValue:[NSNumber numberWithInt:0] forKey:kAsyncPostFlag];
			break;
          }
	}
    [postsArray writeToFile:postTitlesPath atomically:YES];
	[self loadPostTitlesForCurrentBlog];	
	if(![savedPostId	hasPrefix:@"n"])
		[self fectchNewPost:savedPostId formBlog:[self currentBlog]];
	
	[[self currentBlog] setObject:[NSNumber numberWithInt:[postsArray count]] forKey:@"totalposts"];
}

- (void)removeTempFileForUnSavedPost:(NSString *)postId{
	
    NSString *postTitlesPath = [self pathToPostTitles:[self currentBlog]];
    NSMutableArray *postsArray=[NSMutableArray arrayWithContentsOfFile:postTitlesPath];
    int postsCount=[postsArray count];
    for(int i=0;i<postsCount;i++)
    {
        NSMutableDictionary *postDict=[postsArray objectAtIndex:i];
        if([[postDict valueForKey:@"postid"] isEqualToString:postId]){
            [postsArray removeObjectAtIndex:i];
			[postsArray writeToFile:postTitlesPath atomically:YES];
			break;
		}  
	}
}
- (void)restoreUnsavedDraft
{
	[self setCurrentPost:[self currentUnsavedDraft]];
	currentPostIndex= -1;
	[currentPost setObject:@"Local Draft" forKey:@"post_status"];
	[self saveCurrentPostAsDraft];
}
		
//taking post as arg. will help us in implementing async in future.
- (BOOL)savePost:(id)aPost
{
 	BOOL successFlag = NO;
	
	if( ![self appendImagesToPostDescription:aPost] )
	{
 		return successFlag;
	}
	
	NSNumber *postStatus = [aPost valueForKey:@"isLocalDraft"];
	if (currentPostIndex == -1 || ([postStatus intValue] == 1))
	{
		NSMutableDictionary *postParams = [NSMutableDictionary dictionary];
		
		NSString *title = [aPost valueForKey:@"title"];
		title = (title == nil ? @"" : title );
		[postParams setObject:title forKey:@"title"];
		
		NSString *tags = [aPost valueForKey:@"mt_keywords"];
		tags = (tags == nil ? @"" : tags );
		[postParams setObject:tags forKey:@"mt_keywords"];
		
		NSString *description = [aPost valueForKey:@"description"];
		description = (description == nil ? @"" : description );
		[postParams setObject:description forKey:@"description"];
 		[postParams setObject:[aPost valueForKey:@"categories"] forKey:@"categories"];
		
		NSDate *date = [aPost valueForKey:@"date_created_gmt"];
		NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
		NSDate *gmtDate = [date addTimeInterval:(secs*-1)];
		//[postParams setObject:gmtDate forKey:@"dateCreated"];
		[postParams setObject:gmtDate forKey:@"date_created_gmt"];
		
		NSString *post_status = [aPost valueForKey:@"post_status"];		
		if ( !post_status || [post_status isEqualToString:@""] )
			post_status = @"publish";
		[postParams setObject:post_status forKey:@"post_status"];
		
		[postParams setObject:[[aPost valueForKey:@"not_used_allow_comments"] stringValue] forKey:@"not_used_allow_comments"];
		[postParams setObject:[[aPost valueForKey:@"not_used_allow_pings"] stringValue] forKey:@"not_used_allow_pings"];
		[postParams setObject:[aPost valueForKey:@"wp_password"] forKey:@"wp_password"];
		NSString *draftId = [aPost valueForKey:@"draftid"];
		NSDictionary *draftPost = [self currentPost];
		NSArray *args = [NSArray arrayWithObjects:[currentBlog valueForKey:@"blogid"],
						 [currentBlog valueForKey:@"username"],
						 [currentBlog valueForKey:@"pwd"],
						 postParams,
						 nil
						 ];
		
		//TODO: take url from current post
		XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[currentBlog valueForKey:@"xmlrpc"]]];
		[request setMethod:@"metaWeblog.newPost" withObjects:args];
		
		id response = [self executeXMLRPCRequest:request byHandlingError:YES];
		[request release];
		
		//if it is a draft and we successfully published then remove from drafts.
		if(![response isKindOfClass:[NSError class]] ){
			
			successFlag = YES;
			NSMutableArray *draftTitles = [self draftTitlesForBlog:currentBlog];
			int draftsCount = [draftTitles count];
			for(int i = 0;i < draftsCount;i++){
				NSDictionary *draftDict=[draftTitles objectAtIndex:i];
				if([[draftDict valueForKey:@"draftid"] isEqualToString:draftId]){
					[draftTitles removeObjectAtIndex:i];
					[draftTitles writeToFile:[self pathToDraftTitlesForBlog:currentBlog] atomically:YES];
					[currentBlog setObject:[NSNumber numberWithInt:[draftTitles count]] forKey:kDraftsCount];
					[self saveBlogData];
					NSString *pathToPost = [self pathToDraft:draftPost forBlog:currentBlog];
					NSFileManager *defaultFileManager = [NSFileManager defaultManager];
					if([defaultFileManager fileExistsAtPath:pathToPost])
						[defaultFileManager removeItemAtPath:pathToPost error:nil];
					break;
				}
			}
		}
		[self fectchNewPost:response formBlog:currentBlog];
        //[currentPost setValue:response forKey:@"postid"];
	}
	else
	{
        [currentPost setValue:[aPost valueForKey:@"userid"] forKey:@"userid"];
		
		
		//Added for resolving Ticket#113.
		if([aPost valueForKey:@"sticky"]!=nil)
		{
			if([[aPost valueForKey:@"sticky"]intValue]==0)
			{
				[aPost setValue:[NSNumber numberWithInt:0] forKey:@"sticky"];
			}
			else
			{
				[aPost setValue:[NSNumber numberWithInt:1] forKey:@"sticky"];
			}
		}
		
		NSDate *date = [aPost valueForKey:@"date_created_gmt"];
		NSInteger secs = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
		NSDate *gmtDate = [date addTimeInterval:(secs*-1)];
		[aPost setObject:gmtDate forKey:@"date_created_gmt"];
		
		NSString *post_status = [aPost valueForKey:@"post_status"];
		if ( !post_status || [post_status isEqualToString:@""] ) 
			post_status = @"publish";
		[currentPost setObject:post_status forKey:@"post_status"];
		NSArray *args = [NSArray arrayWithObjects:[currentPost valueForKey:@"postid"],
						 [currentBlog valueForKey:@"username"],
						 [currentBlog valueForKey:@"pwd"],
						 aPost,
						 nil
						 ];
		//TODO: take url from current post
		XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[currentBlog valueForKey:@"xmlrpc"]]];
		[request setMethod:@"metaWeblog.editPost" withObjects:args];
		
 		id response = [self executeXMLRPCRequest:request byHandlingError:YES];
		[request release];
		if( ![response isKindOfClass:[NSError class]] )
		{
			//Commented aginst Ticket#--114
//			[self fectchNewPost:[currentPost valueForKey:@"postid"] formBlog:currentBlog];
			successFlag = YES;
		}
	}
 	
	return successFlag;
}

- (void)resetCurrentPage {
	currentPage = nil;                
	currentPageIndex = -2;
}


- (void)resetCurrentPost {
	currentPost = nil;                
	currentPostIndex = -2;
}

- (NSMutableDictionary *) postTitleForPost:(NSDictionary *)aPost 
{
	NSMutableDictionary *postTitle = [NSMutableDictionary dictionary];
	
	/*
	 self->postFieldNames = [NSArray arrayWithObjects:@"local_status", @"dateCreated", @"userid", 
	 @"postid", @"description", @"title", @"permalink", 
	 @"slug", @"wp_password", @"authorid", @"status", 
	 @"mt_excerpt", @"mt_text_more", @"mt_keywords", 
	 @"not_used_allow_comments", @"link_to_comments", @"not_used_allow_pings",@"dateUpdated", 
	 @"blogid", @"blog_host_name", @"wp_author_display_name", nil];
	 */
	/*
	 
	 self->postTitleFieldNames = [NSArray arrayWithObjects:@"local_status", @"dateCreated", @"blogid",  @"blog_host_name", 
	 @"blogName", @"postid", @"title", @"authorid", @"wp_author_display_name", @"status", 
	 @"mt_excerpt", @"mt_keywords", @"date_created_gmt", 
	 @"newcomments", @"totalcomments",nil];
	 
	 */
	
	
	//NSString *dateCreated = [aPost valueForKey:@"dateCreated"];
	//[postTitle setObject:(dateCreated?dateCreated:@"") forKey:@"date_created_gmt"];
	
	NSString *blogid = [aPost valueForKey:@"blogid"];
	[postTitle setObject:(blogid?blogid:@"") forKey:@"blogid"];
	
	NSString *blogHost = [aPost valueForKey:@"blog_host_name"];
	[postTitle setObject:(blogHost?blogHost:@"") forKey:@"blog_host_name"];
	
	NSString *blogName = [[self blogForId:blogid hostName:blogHost] valueForKey:@"blogName"];
	[postTitle setObject:(blogName?blogName:@"") forKey:@"blogName"];

	
	NSString *postid = [aPost valueForKey:@"postid"];
    
     
	[postTitle setObject:(postid?postid:@"") forKey:@"postid"];
	
	// <-- TITLE - first 50 non-WS chars of title or description
	NSCharacterSet *whitespaceCS = [NSCharacterSet whitespaceCharacterSet];
	
	NSString *title = [[aPost valueForKey:@"title"] stringByTrimmingCharactersInSet:whitespaceCS];
//	NSString *description = [[aPost valueForKey:@"description"]
//											stringByTrimmingCharactersInSet:whitespaceCS];
	NSString *trimTitle;
	if ([title length] > 0) {
		
		trimTitle = ([title length] > 50)?[[title substringToIndex:50] stringByAppendingString:@"..."]
										 :title;
		
	} else {
		
		trimTitle = @"(no title)";//([description length] > 50)?[[description substringToIndex:50] stringByAppendingString:@"..."]
									//		   :description;
	}
	
	
	[postTitle setObject:(trimTitle?trimTitle:@"") forKey:@"title"];
	//------ TITLE -->

	NSString *authorid = [aPost valueForKey:@"wp_authorid"];
	[postTitle setObject:(authorid?authorid:@"") forKey:@"wp_authorid"];

	NSString *authorDisplayName = [aPost valueForKey:@"wp_author_display_name"];
	[postTitle setObject:(authorDisplayName?authorDisplayName:@"") forKey:@"wp_author_display_name"];

	NSString *status = [aPost valueForKey:@"post_status"];
	[postTitle setObject:(status?status:@"") forKey:@"post_status"];

	NSString *mtKeywords = [aPost valueForKey:@"mt_keywords"];
	[postTitle setObject:(mtKeywords?mtKeywords:@"") forKey:@"mt_keywords"];
	
	NSString *mtExcerpt = [aPost valueForKey:@"mt_excerpt"];
	[postTitle setObject:(mtExcerpt?mtExcerpt:@"") forKey:@"mt_excerpt"];

	NSNumber *asyncpost = [aPost valueForKey:kAsyncPostFlag];
	[postTitle setObject:(asyncpost?asyncpost:[NSNumber numberWithInt:0]) forKey:kAsyncPostFlag];

    
	NSString *dateCreatedGMT = [aPost valueForKey:@"date_created_gmt"];
	[postTitle setObject:(dateCreatedGMT?dateCreatedGMT:@"") forKey:@"date_created_gmt"];

	NSString *newcomments = [aPost valueForKey:@"newcomments"];
	[postTitle setObject:(newcomments?newcomments:@"0") forKey:@"newcomments"];
	
	NSString *totalcomments = [aPost valueForKey:@"totalcomments"];
	[postTitle setObject:(totalcomments?totalcomments:@"0") forKey:@"totalcomments"];

	return postTitle;	
	
}



#pragma mark -

- (BOOL)createCategory:(NSString *)catTitle parentCategory:(NSString *)parentTitle forBlog:(id)blog
{
	NSDictionary *catParms = [NSMutableDictionary dictionaryWithCapacity:4];
	if( parentTitle && [parentTitle length] ) {
		NSArray *currentCategories = [[self currentBlog] valueForKey:@"categories"];
		int i,catCount = [currentCategories count];
		for(i = 0; i < catCount; i++){
			NSDictionary *dict = [currentCategories objectAtIndex:i];
			if([[dict valueForKey:@"categoryName"] isEqualToString:parentTitle]){
				[catParms setValue:[dict valueForKey:@"categoryId"] forKey:@"parent_id"];
				break;
			}
		}
	}
	
	[catParms setValue:catTitle forKey:@"name"];
	[catParms setValue:catTitle forKey:@"description"];
		
	NSArray *args = [NSArray arrayWithObjects:[blog valueForKey:@"blogid"],
					 [blog valueForKey:@"username"],
					 [blog valueForKey:@"pwd"],
					 catParms,
					 nil
					 ];
 	XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[blog valueForKey:@"xmlrpc"]]];
	[request setMethod:@"wp.newCategory" withObjects:args];
	
	id response = [self executeXMLRPCRequest:request byHandlingError:YES];
	[request release]; 
	if( [response isKindOfClass:[NSError class]] )
	{
 		return NO;
	}
	
	// invoke wp.getCategories
	[self downloadAllCategoriesForBlog:blog];
	return YES;
}
- (void)downloadAllCategoriesForBlog:(id)aBlog{
	
	NSArray *args = [NSArray arrayWithObjects:[aBlog valueForKey:@"blogid"],
					 [aBlog valueForKey:@"username"],
					 [aBlog valueForKey:@"pwd"],
					 nil];
	XMLRPCRequest *reqCategories = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:[aBlog valueForKey:@"xmlrpc"]]];
	[reqCategories setMethod:@"wp.getCategories" withObjects:args];
	
	NSArray *categories = [self executeXMLRPCRequest:reqCategories byHandlingError:YES];
	[reqCategories release];
	if( [categories isKindOfClass:[NSArray class]] ) //might be an error.
	{
		[aBlog setObject:categories forKey:@"categories"];
	}
	
	[self saveBlogData];
}

#pragma mark -
#pragma mark pictures

- (void)resetPicturesList {
	[photosDB removeAllObjects];
	[self resetCurrentPicture];
}

- (NSDictionary *)pictureAtIndex:(NSUInteger)theIndex{
	return [photosDB objectAtIndex:theIndex];
}

- (void)makePictureAtIndexCurrent:(NSUInteger)theIndex {
 	[self setCurrentPicture:(NSMutableDictionary*)[self pictureAtIndex:theIndex]];
}

- (void)makeNewPictureCurrent {
	NSArray *pictureInitValues = [NSArray arrayWithObjects:@"", @"", @"untitled",[NSMutableDictionary dictionary], @"", nil];	
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjects:pictureInitValues forKeys:[self pictureFieldNames]];
	
	// setCurrentBlog will release current reference and make a mutable copy of this one
	[self setCurrentPicture:dict];
	currentPictureIndex = -1;
}

- (int)currentPictureIndex {
	return currentPictureIndex;
}

- (void)setCurrentPictureIndex:(int)anIndex {
	currentPictureIndex = anIndex;
}

- (void)saveCurrentPicture {
	// save it to the current index if set or add it 
}

- (int)countOfPictures {
	return [photosDB count];
}

- (void)resetCurrentPicture {
	currentPicture = nil;
	currentPictureIndex = -2;
}

- (void)addValueToCurrentPicture:(id)anObject forKey:(NSString *)aKey {
	if ([aKey isEqualToString:pictureSize] || [aKey isEqualToString:pictureFileSize])
		[[currentPicture objectForKey:pictureInfo] setObject:anObject forKey:aKey];
	else
		[currentPicture setObject:anObject forKey:aKey];
}

- (NSString *)statusStringForPicture:(id)aPictObj
{
	switch ([[aPictObj valueForKey:pictureStatus] intValue])
	{
		case -1:
			return [NSString stringWithFormat:@"Uploading err:%@", [aPictObj valueForKey:@"faultString"]];
		case 0:
			return @"Locally Saved";
		case 1:
			return @"Uploadeding to WordPress";
		case 2:
			return @"Uploaded to WordPress";
		default:
			break;
	}
	
	return @"";
}

#pragma mark Pictures List
- (void)loadPictures {
	[self loadPhotosDB];
}


#pragma mark Override mutable collection set methods to make mutableCopy

- (void)setBlogsList:(NSMutableArray *)newArray
{
    if (blogsList != newArray)
    {
        [blogsList release];
        blogsList = [newArray retain];
	}
}

- (void)setPageTitlesList:(NSMutableArray *)newArray
{
    if (pageTitlesList != newArray)
    {
        [pageTitlesList release];
        pageTitlesList = [newArray retain];
    }
}

- (void)setPostTitlesList:(NSMutableArray *)newArray
{
    if (postTitlesList != newArray)
    {
        [postTitlesList release];
        postTitlesList = [newArray retain];
    }
}

- (void)setCommentTitlesList:(NSMutableArray *)newArray
{
    if (commentTitlesList != newArray)
    {
        [commentTitlesList release];
        commentTitlesList = [newArray retain];
    }
}

- (void)setDraftTitlesList:(NSMutableArray *)newArray
{
	if (draftTitlesList != newArray)
    {
		[newArray retain];
		[draftTitlesList release];
		draftTitlesList = newArray;
	}
}

- (void)setPageDraftTitlesList:(NSMutableArray *)newArray
{
	if (pageDraftTitlesList != newArray)
    {
		[newArray retain];
		[pageDraftTitlesList release];
		pageDraftTitlesList = newArray;
	}
}


- (void)setPhotosDB:(NSMutableArray *)newArray
{
	if (photosDB != newArray)
	{
		[photosDB release];
		photosDB = [newArray mutableCopy];
	}
}

- (void) setCurrentBlog:(NSMutableDictionary *)aBlog {
	
	if (currentBlog != aBlog)
    {
        [currentBlog release];
        currentBlog = [aBlog retain];
    }
}

- (void) setCurrentPost:(NSMutableDictionary *)aPost {
	
	if (currentPost != aPost)
    {
        [currentPost release];
        currentPost = [aPost retain];
    }
}

- (void) setCurrentPicture:(NSMutableDictionary *)aPicture {

	if (currentPicture != aPicture)
	{
		[currentPicture release];
		currentPicture = [aPicture mutableCopy];
	}
}


#pragma mark util methods

- (NSArray *)uniqueArray:(NSArray *)array
{
	int i, count = [array count];
	NSMutableArray *a = [NSMutableArray arrayWithCapacity:[array count]];
	id curOBj = nil;
	
	for( i = 0; i < count; i++ )
	{
		curOBj = [array objectAtIndex:i];
		if( ![a containsObject:curOBj] )
			[a addObject:curOBj];
	}
	
	return a;
}

- (NSString *)statusDescriptionForStatus:(NSString *)curStatus fromBlog:(id)aBlog
{
	if( [curStatus isEqual:@"Local Draft"] )
		return curStatus;
	NSDictionary *postStatusList = [aBlog valueForKey:@"postStatusList"];
	return [postStatusList valueForKey:curStatus];
}

- (NSString *)pageStatusDescriptionForStatus:(NSString *)curStatus fromBlog:(id)aBlog
{
	if( [curStatus isEqual:@"Local Draft"] )
		return curStatus;
	NSDictionary *pageStatusList = [aBlog valueForKey:@"pageStatusList"];
	return [pageStatusList valueForKey:curStatus];
}


- (NSString *)statusForStatusDescription:(NSString *)statusDescription fromBlog:(id)aBlog
{
	if( [statusDescription isEqual:@"Local Draft"] )
		return statusDescription;
	NSDictionary *postStatusList = [aBlog valueForKey:@"postStatusList"];
	NSArray *dataSource = [postStatusList allValues] ;
	int index = [dataSource indexOfObject:statusDescription];
	if( index != -1 )
	{
		return [[postStatusList allKeys] objectAtIndex:index];
	}
	return nil;
}

- (NSString *)pageStatusForStatusDescription:(NSString *)statusDescription fromBlog:(id)aBlog
{
	if( [statusDescription isEqual:@"Local Draft"] )
		return statusDescription;
	NSDictionary *pageStatusList = [aBlog valueForKey:@"pageStatusList"];
	NSArray *dataSource = [pageStatusList allValues] ;
	int index = [dataSource indexOfObject:statusDescription];
	if( index != -1 )
	{
		return [[pageStatusList allKeys] objectAtIndex:index];
	}
	return nil;
}

- (BOOL) syncCommentsForCurrentBlog {
	[currentBlog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];

	[self syncCommentsForBlog:currentBlog];
	[currentBlog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];

	[self makeBlogAtIndexCurrent:currentBlogIndex];
	return YES;
}

// sync comments for a given blog
- (BOOL) syncCommentsForBlog:(id)blog {
	
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	NSDictionary *commentsStructure = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kNumberOfCommentsToDisplay] forKey:@"number"];
	
 	
	//  ------------------------- invoke metaWeblog.getRecentPosts
	XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
	[postsReq setMethod:[NSString stringWithFormat:@"wp.getComments"] 
			withObjects:[NSArray arrayWithObjects:blogid,username, pwd, commentsStructure,nil]];
	
	NSMutableArray *commentsReceived = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
	[postsReq release];
	// TODO:
	// Check for fault
	// check for nil or empty response
	// provide meaningful messge to user
	if ((!commentsReceived) || !([commentsReceived isKindOfClass:[NSArray class]]) ) {
 		[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//		[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
		return NO;
	}
	
	NSMutableArray *commentsList = [NSMutableArray arrayWithArray:commentsReceived];
 	
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];

	NSMutableArray *commentTitlesArray = [NSMutableArray array];
	
	for ( NSDictionary *comment in commentsList ) {
		// add blogid and blog_host_name to post
		NSMutableDictionary *updatedComment = [NSMutableDictionary dictionaryWithDictionary:comment];
		
		[updatedComment setValue:[blog valueForKey:@"blogid"] forKey:@"blogid"];
		[updatedComment setValue:[blog valueForKey:@"blog_host_name"] forKey:@"blog_host_name"];
		
		NSString *path = [self commentFilePath:updatedComment forBlog:blog];

		[defaultFileManager removeItemAtPath:path error:nil];
		[updatedComment writeToFile:path atomically:YES];
		
		[commentTitlesArray addObject:[self commentTitleForComment:updatedComment]];
	}

	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[commentTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	NSString *pathToCommentTitles = [self pathToCommentTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	[commentTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
 	
	//[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}

- (NSMutableDictionary *) commentTitleForComment:(NSDictionary *)aComment 
{
	NSMutableDictionary *commentTitle = [NSMutableDictionary dictionary];
	
	NSString *blogid = [aComment valueForKey:@"blogid"];
	[commentTitle setObject:(blogid?blogid:@"") forKey:@"blogid"];
	
	NSString *blogHost = [aComment valueForKey:@"blog_host_name"];
	[commentTitle setObject:(blogHost?blogHost:@"") forKey:@"blog_host_name"];
	
	NSString *blogName = [[self blogForId:blogid hostName:blogHost] valueForKey:@"blogName"];
	[commentTitle setObject:(blogName?blogName:@"") forKey:@"blogName"];
	
	
	NSString *commentid = [aComment valueForKey:@"comment_id"];
	[commentTitle setObject:(commentid?commentid:@"") forKey:@"comment_id"];

	NSString *author = [aComment valueForKey:@"author"];
	[commentTitle setObject:(author?author:@"") forKey:@"author"];
	
	NSString *authorEmail = [aComment valueForKey:@"author_email"];
	[commentTitle setObject:(authorEmail?authorEmail:@"") forKey:@"author_email"];

	NSString *status = [aComment valueForKey:@"status"];
	[commentTitle setObject:(status?status:@"") forKey:@"status"];

	NSString *posttitle = [aComment valueForKey:@"post_title"];
	[commentTitle setObject:(posttitle?posttitle:@"") forKey:@"post_title"];

	NSString *dateCreated = [aComment valueForKey:@"date_created_gmt"];
	[commentTitle setObject:(dateCreated?dateCreated:@"") forKey:@"date_created_gmt"];

	NSString *content = [aComment valueForKey:@"content"];
	[commentTitle setObject:(content?content:@"") forKey:@"content"];

	return commentTitle;	
}


// delete comment for a given blog
- (BOOL) deleteComment:(NSArray *) aComment forBlog:(id)blog {

	
//function wp_deleteComment($args) { 
//	$this->escape($args); 
//	$blog_id        = (int) $args[0]; 
//	$username       = $args[1]; 
//	$password       = $args[2]; 
//	$comment_ID     = (int) $args[3]; 	
//}	
	
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	[blog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	NSMutableArray *commentTitlesArray = commentTitlesList;
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	NSMutableArray *commentsReqArray=[[NSMutableArray alloc]init];
	
	int commentsCount=[aComment count];
	for(int i=0;i<commentsCount;i++)
	{
		NSDictionary *commentsDict=[aComment objectAtIndex:i];
		NSString *commentid = [commentsDict valueForKey:@"comment_id"];
		
		NSMutableDictionary *dict=[[NSMutableDictionary alloc]init];
		[dict setValue:@"wp.deleteComment" forKey:@"methodName"];
		[dict setValue:[NSArray arrayWithObjects:blogid,username, pwd, commentid,nil] forKey:@"params"];
		[commentsReqArray addObject:dict];
		[dict release];
	}

	if(commentsCount>0){
		XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
		[postsReq setMethod:@"system.multicall" withObject:commentsReqArray];
		id result = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
		[postsReq release];
 		
		// TODO:
		// Check for fault
		// check for nil or empty response
		// provide meaningful messge to user
		if ((!result) || !([result isKindOfClass:[NSArray class]]) ) {
 			[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//			[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
			return NO;
		}else {
			for(int i=0;i<commentsCount;i++)
			{
				NSDictionary *commentsDict=[aComment objectAtIndex:i];
				NSString *path = [self commentFilePath:commentsDict forBlog:blog];
				[defaultFileManager removeItemAtPath:path error:nil];
				[commentTitlesList removeObject:commentsDict];
			}
		}
	}
	
	NSString *pathToCommentTitles = [self pathToCommentTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];

	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[commentTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	[commentTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
 	[commentsReqArray release];
	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}

// approve comment for a given blog
- (BOOL) approveComment:(NSMutableArray *) aComment forBlog:(id)blog {
	
//function wp_editComment($args) { 
//	 $blog_id        = (int) $args[0]; 
//	 $username       = $args[1]; 
//	$password       = $args[2]; 
//	$comment_ID     = (int) $args[3]; 
//	$content_struct = $args[4]; 	
//}
	[blog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	NSMutableArray *commentTitlesArray = commentTitlesList;
	int commentsCount,i,count = [commentTitlesArray count];
	NSMutableArray *commentsReqArray=[[NSMutableArray alloc]init];
	 commentsCount=[aComment count];
	 for(i=0;i<commentsCount;i++)
	 {
		 NSMutableDictionary *commentsDict=[aComment objectAtIndex:i];
		 NSString *commentid = [commentsDict valueForKey:@"comment_id"];
		 NSString *commentFilePath = [self commentFilePath:commentsDict forBlog:blog];
		 NSDictionary *completeComment = [NSMutableDictionary dictionaryWithContentsOfFile:commentFilePath];
		 
		 if([[commentsDict valueForKey:@"status"]isEqualToString:@"approve"]){
			 [aComment removeObjectAtIndex:i];
			 commentsCount--;i--;
			 continue;
		 }
				 
		 [commentsDict setValue:@"approve" forKey:@"status"];
		 [completeComment setValue:@"approve" forKey:@"status"];
		 
		 NSMutableDictionary *dict=[[NSMutableDictionary alloc]init];
		 [dict setValue:@"wp.editComment" forKey:@"methodName"];
		 [dict setValue:[NSArray arrayWithObjects:blogid,username, pwd, commentid,completeComment,nil] forKey:@"params"];
		 [commentsReqArray addObject:dict];
			
		 [dict release];
	 }
	 commentsCount=[aComment count];
 	 if(commentsCount>0){
		 XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
		 [postsReq setMethod:@"system.multicall" withObject:commentsReqArray];
		 id result = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
		 [postsReq release];
 
		 // TODO:
		 // Check for fault
		 // check for nil or empty response
		 // provide meaningful messge to user
		 if ((!result) || !([result isKindOfClass:[NSArray class]]) ) {
 		 [blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//		 [[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
		 return NO;
		 }else{
			 for(int j=0;j<commentsCount;j++){
				 NSDictionary *commentDict=[aComment objectAtIndex:j];
				 for ( i = 0; i < count; i++ ) {
					 NSDictionary *dict = [commentTitlesArray objectAtIndex:i];
					 if ( [[dict valueForKey:@"comment_id"] isEqualToString:[commentDict valueForKey:@"comment_id"]] )
						 [commentTitlesArray replaceObjectAtIndex:i withObject:commentDict];
				 }
			 }
		 }
	 }

	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[commentTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	NSString *pathToCommentTitles = [self pathToCommentTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	[commentTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
 	[commentsReqArray release];
	
	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}


// approve comment for a given blog
- (BOOL) unApproveComment:(NSMutableArray *) aComment forBlog:(id)blog {
	
	//function wp_editComment($args) { 
	//	 $blog_id        = (int) $args[0]; 
	//	 $username       = $args[1]; 
	//	$password       = $args[2]; 
	//	$comment_ID     = (int) $args[3]; 
	//	$content_struct = $args[4]; 	
	//}
	[blog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	NSMutableArray *commentTitlesArray = commentTitlesList;
	int count = [commentTitlesArray count];
	int i=0,commentsCount=[aComment count];
				
	NSMutableArray *commentsReqArray=[[NSMutableArray alloc]init];
	for(i=0;i<commentsCount;i++)
	{
		NSMutableDictionary *commentsDict=[aComment objectAtIndex:i];
		NSString *commentid = [commentsDict valueForKey:@"comment_id"];
		NSString *commentFilePath = [self commentFilePath:commentsDict forBlog:blog];
		NSDictionary *completeComment = [NSMutableDictionary dictionaryWithContentsOfFile:commentFilePath];
		
		if([[commentsDict valueForKey:@"status"]isEqualToString:@"hold"]){
			[aComment removeObjectAtIndex:i];
			commentsCount--;i--;
			continue;
		}
		
		[commentsDict setValue:@"hold" forKey:@"status"];
		[completeComment setValue:@"hold" forKey:@"status"];
		
		NSMutableDictionary *dict=[[NSMutableDictionary alloc]init];
		[dict setValue:@"wp.editComment" forKey:@"methodName"];
		[dict setValue:[NSArray arrayWithObjects:blogid,username, pwd, commentid,completeComment,nil] forKey:@"params"];
		[commentsReqArray addObject:dict];
		[dict release];
	}
	commentsCount=[aComment count];
	if(commentsCount>0){
		XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
		[postsReq setMethod:@"system.multicall" withObject:commentsReqArray];
		id result = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
		[postsReq release];
 		
		// TODO:
		// Check for fault
		// check for nil or empty response
		// provide meaningful messge to user
		if ((!result) || !([result isKindOfClass:[NSArray class]]) ) {
 			[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
			return NO;
		}else{
			for(int j=0;j<commentsCount;j++){
				NSDictionary *commentDict=[aComment objectAtIndex:j];
				for ( i = 0; i < count; i++ ) {
					NSDictionary *dict = [commentTitlesArray objectAtIndex:i];
					if ( [[dict valueForKey:@"comment_id"] isEqualToString:[commentDict valueForKey:@"comment_id"]] )
						[commentTitlesArray replaceObjectAtIndex:i withObject:commentDict];
				}
			}
			
		}
	}	
		
	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[commentTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	NSString *pathToCommentTitles = [self pathToCommentTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	[commentTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
 	[commentsReqArray release];
	
	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}

// approve comment for a given blog
- (BOOL) spamComment:(NSMutableArray *) aComment forBlog:(id)blog {
	
	//function wp_editComment($args) { 
	//	 $blog_id        = (int) $args[0]; 
	//	 $username       = $args[1]; 
	//	$password       = $args[2]; 
	//	$comment_ID     = (int) $args[3]; 
	//	$content_struct = $args[4]; 	
	//}
	[blog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	// Parameters
	NSString *username = [blog valueForKey:@"username"];
	NSString *pwd = [blog valueForKey:@"pwd"];
	NSString *fullURL = [blog valueForKey:@"xmlrpc"];
	NSString *blogid = [blog valueForKey:@"blogid"];
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	NSMutableArray *commentTitlesArray = commentTitlesList;
	int i=0,commentsCount=[aComment count];
	
	NSMutableArray *commentsReqArray=[[NSMutableArray alloc]init];
	for(i=0;i<commentsCount;i++)
	{
		NSMutableDictionary *commentsDict=[aComment objectAtIndex:i];
		NSString *commentid = [commentsDict valueForKey:@"comment_id"];
		NSString *commentFilePath = [self commentFilePath:commentsDict forBlog:blog];
		NSDictionary *completeComment = [NSMutableDictionary dictionaryWithContentsOfFile:commentFilePath];
	// Commented code to resolve the issue mentioned in Ticket#97
//		if([[commentsDict valueForKey:@"status"]isEqualToString:@"spam"]){
//			[aComment removeObjectAtIndex:i];
//			commentsCount--;i--;
//			continue;
//		}
//			
//		[commentsDict setValue:@"spam" forKey:@"status"];
		[completeComment setValue:@"spam" forKey:@"status"];
		
		NSMutableDictionary *dict=[[NSMutableDictionary alloc]init];
		[dict setValue:@"wp.editComment" forKey:@"methodName"];
		[dict setValue:[NSArray arrayWithObjects:blogid,username, pwd, commentid,completeComment,nil] forKey:@"params"];
		[commentsReqArray addObject:dict];
		[dict release];
	}
	commentsCount=[aComment count];
	if(commentsCount>0){
		XMLRPCRequest *postsReq = [[XMLRPCRequest alloc] initWithHost:[NSURL URLWithString:fullURL]];
		[postsReq setMethod:@"system.multicall" withObject:commentsReqArray];
		id result = [self executeXMLRPCRequest:postsReq byHandlingError:YES];
		[postsReq release];
 		
		// TODO:
		// Check for fault
		// check for nil or empty response
		// provide meaningful messge to user
		if ((!result) || !([result isKindOfClass:[NSArray class]]) ) {
 			[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
//			[[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:blog userInfo:nil];
			return NO;
		}else {
			for(i=0;i<commentsCount;i++){
				NSDictionary *dict=[aComment objectAtIndex:i];
				NSString *path = [self commentFilePath:dict forBlog:blog];
				[defaultFileManager removeItemAtPath:path error:nil];
				[commentTitlesList removeObject:dict];
				[commentTitlesArray removeObject:dict];
			}
		}
	}
	
	// sort and save the postTitles list
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:NO];
	[commentTitlesArray sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	NSString *pathToCommentTitles = [self pathToCommentTitles:blog];
	[defaultFileManager removeItemAtPath:pathToCommentTitles error:nil];
	[commentTitlesArray writeToFile:pathToCommentTitles  atomically:YES];
 	[commentsReqArray release];
	
	[blog setObject:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	return YES;
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
 	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	[delegate setAlertRunning:NO];
}

- (void)wrapperForSyncPagesAndCommentsForBlog:(id)aBlog
{
	NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
	BOOL supportsPagesAndComments = NO;
	[aBlog setValue:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
	[self checkXML_RPC_URL_IsRunningSupportedVersionOfWordPress: [self discoverxmlrpcurlForurl:[aBlog valueForKey:@"url"]] withPagesAndCommentsSupport:&supportsPagesAndComments];
	[aBlog setValue:[NSNumber numberWithInt:0] forKey:@"kIsSyncProcessRunning"];
	if( supportsPagesAndComments )
	{
		[aBlog setValue:[NSNumber numberWithBool:YES]   forKey:kSupportsPagesAndCommentsServerCheck];
	}
	[aBlog setValue:[NSNumber numberWithBool:supportsPagesAndComments]   forKey:kSupportsPagesAndComments];
	[self saveCurrentBlog];
	[self performSelectorOnMainThread:@selector(postBlogsRefreshNotificationInMainThread:) withObject:aBlog waitUntilDone:YES];

	[ap release];
}


- (UIImage *)scaleAndRotateImage:(UIImage *)image
{
	[image retain];
	int kMaxResolution = 640; // Or whatever
	
	CGImageRef imgRef = image.CGImage;
	
	CGFloat width = CGImageGetWidth(imgRef);
	CGFloat height = CGImageGetHeight(imgRef);
	
	CGAffineTransform transform = CGAffineTransformIdentity;
	CGRect bounds = CGRectMake(0, 0, width, height);
	
	NSNumber	 *number = [currentPost valueForKey:kResizePhotoSetting];
	
	if ( !number ) { // If post doesn't contain this key
		number = [currentBlog valueForKey:kResizePhotoSetting];
		if ( !number ) {// If blog doesn't contain this key
			number = [NSNumber numberWithInt:0];
		}
		
	}
	
	BOOL shouldResize = [number boolValue];
	
	if ( shouldResize ) { // Resize the photo only when user opts this setting
		if (width > kMaxResolution || height > kMaxResolution) {
			CGFloat ratio = width/height;
			if (ratio > 1) {
				bounds.size.width = kMaxResolution;
				bounds.size.height = bounds.size.width / ratio;
			}
			else {
				bounds.size.height = kMaxResolution;
				bounds.size.width = bounds.size.height * ratio;
			}
		}
	}
	
	CGFloat scaleRatio = bounds.size.width / width;
	CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
	CGFloat boundHeight;
	UIImageOrientation orient = image.imageOrientation;
	switch(orient) {
			
		case UIImageOrientationUp: //EXIF = 1
			transform = CGAffineTransformIdentity;
			break;
			
		case UIImageOrientationUpMirrored: //EXIF = 2
			transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
			transform = CGAffineTransformScale(transform, -1.0, 1.0);
			break;
			
		case UIImageOrientationDown: //EXIF = 3
			transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
			transform = CGAffineTransformRotate(transform, M_PI);
			break;
			
		case UIImageOrientationDownMirrored: //EXIF = 4
			transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
			transform = CGAffineTransformScale(transform, 1.0, -1.0);
			break;
			
		case UIImageOrientationLeftMirrored: //EXIF = 5
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
			transform = CGAffineTransformScale(transform, -1.0, 1.0);
			transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
			break;
			
		case UIImageOrientationLeft: //EXIF = 6
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
			transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
			break;
			
		case UIImageOrientationRightMirrored: //EXIF = 7
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeScale(-1.0, 1.0);
			transform = CGAffineTransformRotate(transform, M_PI / 2.0);
			break;
			
		case UIImageOrientationRight: //EXIF = 8
			boundHeight = bounds.size.height;
			bounds.size.height = bounds.size.width;
			bounds.size.width = boundHeight;
			transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
			transform = CGAffineTransformRotate(transform, M_PI / 2.0);
			break;
			
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
			
	}
	
	UIGraphicsBeginImageContext(bounds.size);
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
		CGContextScaleCTM(context, -scaleRatio, scaleRatio);
		CGContextTranslateCTM(context, -height, 0);
	}
	else {
		CGContextScaleCTM(context, scaleRatio, -scaleRatio);
		CGContextTranslateCTM(context, 0, -height);
	}
	
	CGContextConcatCTM(context, transform);
	
	CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
	UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	[image release];
	
	return imageCopy;
}

@end
