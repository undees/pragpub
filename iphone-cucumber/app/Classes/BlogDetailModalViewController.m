#import "BlogDetailModalViewController.h"
#import "Constants.h"
#import "BlogDataManager.h"
#import "WPBlogsListController.h"
#import "WPSelectionTableViewController.h"
#import "WordPressAppDelegate.h"
#import "RootViewController.h"
#import "WPNavigationLeftButtonView.h"
#import "UIViewController+WPAnimation.h"
#import "Reachability.h"
#import "WPLabelFooterView.h"

#define kResizePhotoSettingSectionHeight	 80.0f

@interface BlogDetailModalViewController()
- (void)populateSelectionsControllerWithNoOfRecentPosts;
@end

@implementation BlogDetailModalViewController

@synthesize saveBlogButton;
@synthesize currentEditingTextField;
@synthesize blogEditTable;
@synthesize cancelBlogButton;
@synthesize removeBlogButton;
@synthesize isModal;
@synthesize mode;

- (void)dealloc {
	[saveBlogButton release];
	[super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	//As we are removing from the super view when we add progress indicator, that time retain count of this button will become zero.
	//we need to retain this button so that we can use this again and again.
	[saveBlogButton retain];
	
	BlogDataManager *dm = [BlogDataManager sharedDataManager];
	noOfPostsTextField.text = [[dm currentBlog] valueForKey:kPostsDownloadCount];
	
	
	blogURLTextField.font = [UIFont fontWithName:@"Helvetica" size:15];
	userNameTextField.font = [UIFont fontWithName:@"Helvetica" size:15];
	passwordTextField.font = [UIFont fontWithName:@"Helvetica" size:15];
	noOfPostsTextField.font = [UIFont fontWithName:@"Helvetica" size:15];
	
	blogURLLabel.font = [UIFont boldSystemFontOfSize:17];
	userNameLabel.font = [UIFont boldSystemFontOfSize:17];
	passwordLabel.font = [UIFont boldSystemFontOfSize:17];
	noOfPostsLabel.font = [UIFont boldSystemFontOfSize:17];
	
	resizePhotoLabel.font = [UIFont boldSystemFontOfSize:17.0f];
	
	blogEditTable.scrollEnabled = YES;
	self.navigationController.navigationBarHidden= NO;
    
    WPNavigationLeftButtonView *myview = [WPNavigationLeftButtonView createView];  
    [myview setTarget:self withAction:@selector(cancel:)];
    [myview setTitle:@"Cancel"];
    UIBarButtonItem *barButton  = [[UIBarButtonItem alloc] initWithCustomView:myview];
    self.navigationItem.leftBarButtonItem = barButton;
    [barButton release];
    [myview release];
	self.navigationItem.rightBarButtonItem = saveBlogButton;
	[resizePhotoControl addTarget:self action:@selector(changeResizePhotosOptions) forControlEvents:UIControlEventAllTouchEvents];
}

- (void) changeResizePhotosOptions {
}

- (void)refreshBlogEdit {
	self.navigationItem.rightBarButtonItem.action = @selector(updateBlog:);
}

- (void)refreshBlogCompose {
	self.navigationItem.rightBarButtonItem.action = @selector(saveBlog:);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	// this UIViewController is about to re-appear, make sure we remove the current selection in our table view
	NSIndexPath *tableSelection = [blogEditTable indexPathForSelectedRow];
	
	if( tableSelection != nil )
		[blogEditTable deselectRowAtIndexPath:tableSelection animated:NO];
	
	// we retain this controller in the caller (RootViewController) so load view does not get called 
	// everytime we navigate to the view
	// need to update the prompt and the title here as well as in loadView
	NSString *blogid = [[[BlogDataManager sharedDataManager] currentBlog] valueForKey:@"blogid"];
	if (!blogid || blogid == @"") {
		self.title = NSLocalizedString(@"Add Blog", @"BlogDetailModalViewController_Title_AddBlog");
	} else {
		self.title = NSLocalizedString(@"Edit Blog", @"BlogDetailModalViewController_Title_EditBlog");
	}
	
	[blogEditTable reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (void)viewDidDisappear:(BOOL)animated {
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(mode)
		return 4;
	else 
		return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section == 0)
		return 3;
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	BlogDataManager *sharedDataManager = [BlogDataManager sharedDataManager];
	NSDictionary *currentBlog = [sharedDataManager currentBlog];
	switch (indexPath.row) {
		case 0:;
			if (indexPath.section == 0) {
				NSString *urlString  = [currentBlog objectForKey:@"url"];
				if (urlString) {
					urlString = [urlString stringByReplacingOccurrencesOfString:@"http://" withString:@""];
					urlString = [urlString stringByReplacingOccurrencesOfString:@"/xmlrpc.php" withString:@""];
					blogURLTextField.text = urlString;
				}
				blogURLTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
				return blogURLTableViewCell;
			} else if  (indexPath.section == 2) {
				NSNumber *value = [currentBlog valueForKey:kResizePhotoSetting];
				if ( value == nil ) {
					value = [NSNumber numberWithInt:0];
					[currentBlog setValue:value forKey:kResizePhotoSetting];
				}
				
				resizePhotoControl.on = [value boolValue];
				return resizePhotoViewCell;
				break;
			} else if  (indexPath.section == 3) {
				return removeButtonViewCell;
			} else {
				//				noOfPostsTextField.text = [[sharedDataManager currentBlog] objectForKey:@"pwd"];
				noOfPostsTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
				return noOfPostsTableViewCell;
				break;
			}
			break;
		case 1:
			if (indexPath.section == 0) {
				userNameTextField.text = [currentBlog objectForKey:@"username"];
				userNameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
				return userNameTableViewCell;
			} 
		case 2:
			passwordTextField.text = [currentBlog objectForKey:@"pwd"];
			passwordTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
			return passwordTableViewCell;
			break;
			
		default:
			break;
	}
	
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section 
{
	if (section == 2)
	{
		//This Class creates a view which contains label with color and font attributes and sets the label properties and it is used as footer view for section in tableview.
		WPLabelFooterView *labelView = [[[WPLabelFooterView alloc] initWithFrame:CGRectMake(0,3,300,60)] autorelease];
		//Sets the number of lines to be shown in the label.
		[labelView setNumberOfLines:(NSInteger)3];
		//Sets the text alignment of the label.
		[labelView setTextAlignment:UITextAlignmentCenter];
		//Sets the text for the label.
		[labelView setText:kResizePhotoSettingHintLabel];
		
		return labelView;
	}
	return nil;
}
		
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if( section == 2 )
		return kResizePhotoSettingSectionHeight;		
	return 0.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if  (indexPath.section == 3)
		return 40.0f;
	return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 1) {
		if (self.currentEditingTextField)
			[self.currentEditingTextField resignFirstResponder];	
		
		[self populateSelectionsControllerWithNoOfRecentPosts];
	}
}

- (void)populateSelectionsControllerWithNoOfRecentPosts
{
	WPSelectionTableViewController *selectionTableViewController = [[WPSelectionTableViewController alloc] initWithNibName:@"WPSelectionTableViewController" bundle:nil];
	
	
	BlogDataManager *dm = [BlogDataManager sharedDataManager];
	
	NSArray *dataSource = [NSArray arrayWithObjects:@"10 Recent Posts",@"20 Recent Posts",@"30 Recent Posts",@"40 Recent Posts",@"50 Recent Posts",nil] ;
	
	NSString *curStatus = [[dm currentBlog] valueForKey:kPostsDownloadCount];
	// default value for number of posts is setin BlogDataManager.makeNewBlogCurrent
	NSArray *selObject = ( curStatus == nil ? [NSArray arrayWithObject:[dataSource objectAtIndex:0]] : [NSArray arrayWithObject:curStatus] );	
	[selectionTableViewController populateDataSource:dataSource
									   havingContext:nil
									 selectedObjects:selObject
									   selectionType:kRadio
										 andDelegate:self];
	
	selectionTableViewController.title = @"Status";
	selectionTableViewController.navigationItem.rightBarButtonItem = nil;
	[self.navigationController pushViewController:selectionTableViewController animated:YES];
	[selectionTableViewController release];
}

- (void)selectionTableViewController:(WPSelectionTableViewController *)selctionController completedSelectionsWithContext:(void *)selContext selectedObjects:(NSArray *)selectedObjects haveChanges:(BOOL)isChanged
{
	if( !isChanged )
	{
		[selctionController clean];
		return;
	}
	
	BlogDataManager *dataManager = [BlogDataManager sharedDataManager];
	[[dataManager currentBlog] setObject:[selectedObjects objectAtIndex:0] forKey:kPostsDownloadCount];
	noOfPostsTextField.text = [selectedObjects objectAtIndex:0];
	
	[selctionController clean];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if( buttonIndex == 0 ) //NO
	{
		BlogDataManager *dataManager = [BlogDataManager sharedDataManager];
		[dataManager removeCurrentBlog];
		
		[blogEditTable reloadData];
		[self cancel:nil];		
	}
	else 
	{
	}
}

- (IBAction)removeBlog:(id)sender 
{
	NSString *blogName = [[[BlogDataManager sharedDataManager] currentBlog] valueForKey:@"blogName"];
	NSString *title = nil;
	if( [blogName length] > 0 )
		title = [NSString stringWithFormat:@"Are you sure you want to delete \"%@\" ?", blogName];
	else
		title = [NSString stringWithFormat:@"Are you sure you want to delete this Blog ?"];
	
	UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:title message:@"The blog's setup information and local drafts will be deleted permanently from your iPhone. Posts and drafts on the server will not be affected." delegate:self cancelButtonTitle:nil otherButtonTitles:@"Remove",@"Cancel", nil];
	
	[alert1 show];
	[alert1 release];
}

- (void)cancel:(id)sender {
	if (isModal) {
		[self.navigationController dismissModalViewControllerAnimated:YES];
	}
	else {
		[self popTransition:self.navigationController.view];
	}
}

- (void)addProgressIndicator
{
	NSAutoreleasePool *apool = [[NSAutoreleasePool alloc] init];
	UIActivityIndicatorView *aiv = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	UIBarButtonItem *activityButtonItem = [[UIBarButtonItem alloc] initWithCustomView:aiv];
	[aiv startAnimating]; 
	[aiv release];
	
	self.navigationItem.rightBarButtonItem = activityButtonItem;
	[activityButtonItem release];
	[apool release];
}

- (void)removeProgressIndicator
{
	NSAutoreleasePool *apool = [[NSAutoreleasePool alloc] init];
	
	//wait incase the other thread did not complete its work.
	while (self.navigationItem.rightBarButtonItem == saveBlogButton)
	{
		[[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] addTimeInterval:0.1]];
	}
	
	self.navigationItem.rightBarButtonItem = saveBlogButton;
	
	[apool release];
}

- (void)updateBlog:(id)sender {
	if (self.currentEditingTextField)
		[self.currentEditingTextField resignFirstResponder];	
	
	BlogDataManager *dm = [BlogDataManager sharedDataManager];
	
	// set entered values in current blog
	NSString *username = userNameTextField.text;
	NSString *pwd = passwordTextField.text;
	[dm.currentBlog setValue:(pwd?pwd:@"") forKey:@"pwd"];	
	NSString *url = blogURLTextField.text;
	
	if (!username || !url || !pwd || [username length] ==0 || [url length] == 0 || [pwd length] == 0 ) {
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Please enter values for URL, User Name and Password." 
													   delegate:[[UIApplication sharedApplication] delegate]  cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		[alert release];
		return;
	}
	
	url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	blogURLTextField.text = url;

	NSDictionary *currentBlog = [dm currentBlog];
	NSNumber *value = [NSNumber numberWithBool:resizePhotoControl.on];
	[currentBlog setValue:value forKey:kResizePhotoSetting];
	
	[self performSelectorInBackground:@selector(addProgressIndicator) withObject:nil];
	
	
	// How do I know if there are errors? 
	if( [dm validateCurrentBlog:url user:username password:pwd] )
	{
		// show the updated blog values
		[self.blogEditTable reloadData];
		
		//[dm performSelectorInBackground:@selector(generateTemplateForBlog:) withObject:[[dm.currentBlog copy] autorelease]];
		[dm performSelector:@selector(generateTemplateForBlog:) withObject:[[dm.currentBlog copy] autorelease]];
		
		[dm addSyncPostsForBlogToQueue:dm.currentBlog]; 
		
		//TODO: preview based on template.
		[dm saveCurrentBlog];
		
		[[[WordPressAppDelegate sharedWordPressApp] navigationController] popViewControllerAnimated:YES];
	}
	
	[self performSelectorInBackground:@selector(removeProgressIndicator) withObject:nil];
	
	[blogEditTable reloadData];
	
}

/*
 Login and retrieve data for the blog using blogger.getUserInfo, blogger.getUsersBlogs, wp.getAuthors
 - resign any text field first responder
 - update current blog with the data retrieve
 - save password in keychain
 - if successfully retrieved, enable save button and disable login button
 - show error dialog for bad login/pass or other url related errors
 */

- (void)saveBlog:(id)sender {
	
	if ( [[Reachability sharedReachability] internetConnectionStatus] == NotReachable ) {
		UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:@"Communication Error."
														  message:@"no internet connection."
														 delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert1 show];
		[alert1 release];		
		return;
	}
	
	// save the blog and then invoke dismissModalViewControllerAnimated on the parent nav controller
	
	if (self.currentEditingTextField)
		[self.currentEditingTextField resignFirstResponder];	
	
	BlogDataManager *dm = [BlogDataManager sharedDataManager];
	
	// set entered values in current blog
	NSString *username = userNameTextField.text;
	NSString *pwd = passwordTextField.text;
	[dm.currentBlog setValue:(pwd?pwd:@"") forKey:@"pwd"];	
	NSString *url = blogURLTextField.text;
	
	if (!username || !url || !pwd || [username length] ==0 || [url length] == 0 || [pwd length] == 0 ) {
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
														message:@"Please enter values for URL, User Name and Password." 
													   delegate:[[UIApplication sharedApplication] delegate] cancelButtonTitle:@"OK" otherButtonTitles:nil];
		
		[alert show];
		[alert release];
		return;
	}
	
	url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	blogURLTextField.text = url;

	NSDictionary *currentBlog = [dm currentBlog];
	NSNumber *value = [NSNumber numberWithBool:resizePhotoControl.on];
	[currentBlog setValue:value forKey:kResizePhotoSetting];
	
	if ( mode == 0 ) { // new one -- Check for adding a existing blog again.
		NSDictionary *newBlog = [NSDictionary dictionaryWithObjectsAndKeys:username,@"username",pwd,@"pwd",url,@"url",nil];
			
		if([dm doesBlogExists:newBlog])
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
															message:[NSString stringWithFormat:@"Blog '%@' already configured on this iPhone.", url]
														   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			
			[alert show];
			[alert release];		
			return;
		}
    }
	
	[self performSelectorInBackground:@selector(addProgressIndicator) withObject:nil];
	
	
	// How do I know if there are errors? 
	if( [dm refreshCurrentBlog:url user:username password:pwd] )
	{
		// show the updated blog values
		[self.blogEditTable reloadData];
		
		//[dm performSelectorInBackground:@selector(generateTemplateForBlog:) withObject:[[dm.currentBlog copy] autorelease]];
		//		[dm performSelector:@selector(generateTemplateForBlog:) withObject:[[dm.currentBlog copy] autorelease]];
		
		//		[dm addSyncPostsForBlogToQueue:dm.currentBlog]; 
		
		//see implemention of wrapperForSyncPostsAndGetTemplateForBlog: method for comment

		//UnCommented this line and moved saveCurrentBlog after transition for spinning indicator in the main screen. When a new blog is created.
		[dm.currentBlog setObject:[NSNumber numberWithInt:1] forKey:@"kIsSyncProcessRunning"];
		[dm performSelectorInBackground:@selector(wrapperForSyncPostsAndGetTemplateForBlog:) withObject:dm.currentBlog];

		
		//		WPBlogsListController *blogListController = [[WPBlogsListController alloc] initWithNibName:@"WPBlogsListController" bundle:nil];
		//		[self.navigationController pushViewController:blogListController animated:YES];
		[self popTransition:self.navigationController.view];
		[dm saveCurrentBlog];

		
		//		// Success Message
		//		UIAlertView *alert5 = [[UIAlertView alloc] initWithTitle:@"Success!"
		//														 message:@"Blog was found and saved." 
		//														delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		//		[alert5 show];
		//		[alert5 release];
	}
	
	[self performSelectorInBackground:@selector(removeProgressIndicator) withObject:nil];
	
	[blogEditTable reloadData];
}

- (void)didReceiveMemoryWarning {
	WPLog(@"%@ %@", self, NSStringFromSelector(_cmd));
	[super didReceiveMemoryWarning];
}


#pragma mark <UITextFieldDelegate> Methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	
	if (mode) {
		if (textField.tag == 111 || textField.tag == 112)
			return NO;
	}
	self.currentEditingTextField = textField;
	
	return TRUE;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	// reset tagInEdit - no field in edit
	self.currentEditingTextField = nil;
	
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	
	BlogDataManager *dataManager = [BlogDataManager sharedDataManager];
	
	if (textField.tag == 111) {
		[[dataManager currentBlog] setValue:textField.text forKey:@"url"];
	}
	else if (textField.tag == 112) {
		[[dataManager currentBlog] setValue:textField.text forKey:@"username"];
	}
	else if (textField.tag == 113) {
		[[dataManager currentBlog] setValue:textField.text forKey:@"pwd"];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	if([delegate isAlertRunning] == YES)
		return NO;
	
	// Return YES for supported orientations
	return YES;
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
		[blogEditTable reloadData];
}

@end

