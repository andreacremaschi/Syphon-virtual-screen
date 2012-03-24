//
//  AppDelegate.h
//  EWSyphonVirtualScreen
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class  EWScreenCaptureController, EWVirtualScreenController;
@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
{
    
    IBOutlet NSMenu *menu;

    __unsafe_unretained NSMenuItem *syponStateMenuItem;
}

@property (unsafe_unretained) IBOutlet NSWindow *window;
@property (strong) IBOutlet EWScreenCaptureController* screenCaptureController;
@property (strong) IBOutlet EWVirtualScreenController* virtualScreenController;
@property bool isDriverLoaded;

// preferences
@property bool activateVirtualScreenAtStartup;
@property bool activateSyphonServerAtStartup;

// IBOutlet
@property (unsafe_unretained) IBOutlet NSMenuItem *driverStateMenuItem;
@property (unsafe_unretained) IBOutlet NSOpenGLView *openGLView;
@property (unsafe_unretained) IBOutlet NSMenuItem *syponStateMenuItem;


//IBActions
- (IBAction)toggleVirtualScreen:(id)sender;
- (IBAction)toggleSyphonServer:(id)sender;
- (IBAction)updateFramebuffer:(id)sender;

@end

