//
//  UIMainDialog.h
//  PSPScreenDriverClient
//
//  Created by Enno Welbers on 27.02.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UIMainDialog : NSObject {
	NSString *imgState;
	NSString *driverState;
	NSMutableArray *Profiles;
	NSMutableArray *ProfileNames;
	IBOutlet NSImageView *imgView;
	NSIndexSet *selectedProfile;
	io_service_t service;
	io_connect_t connect;
	unsigned char *driverbuf;
	BOOL bufferOn;
}
@property (nonatomic,retain) NSString *imgState;
@property (nonatomic,retain) NSString *driverState;
@property (nonatomic,retain) NSMutableArray *ProfileNames;
@property (nonatomic,retain) NSIndexSet *selectedProfile;
@property (nonatomic) BOOL bufferOn;
- (IBAction) fetchImage:(id)sender;
- (IBAction) SwitchDriver:(id)sender;
- (int) getMode;
- (EWProxyFramebufferModeInfo*) getCurrentModeInfo;
- (CGImageRef) getCursor;

@end
