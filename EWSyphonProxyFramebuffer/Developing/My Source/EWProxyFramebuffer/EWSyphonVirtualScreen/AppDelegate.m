//
//  AppDelegate.m
//  EWSyphonVirtualScreen
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "EWScreenCaptureController.h"
#import "EWVirtualScreenController.h"

#import "NSObject+BlockObservation.h"

#import "EWProxyFrameBuffer.h"


@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@end


@implementation AppDelegate
@synthesize openGLView;
@synthesize syponStateMenuItem = _syphonStateMenuItem;

@synthesize window = _window;
@synthesize statusItem = _statusItem;
@synthesize screenCaptureController, virtualScreenController;
@synthesize driverStateMenuItem = _driverStateMenuItem;

@synthesize activateVirtualScreenAtStartup;
@synthesize activateSyphonServerAtStartup;

@synthesize isDriverLoaded;

#pragma mark - Status item

- (void) setupStatusItem
{
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    _statusItem = [bar statusItemWithLength: NSSquareStatusItemLength];
    
    //[_statusItem setTitle:@"Status"];
    NSImage *statusImage = [NSImage imageNamed:@"shape_darkgray"];
    [_statusItem setImage: statusImage];
    [_statusItem setHighlightMode:YES];
    
    [_statusItem setMenu:menu];
        
}

- (void) setupMenuItemsDescriptorsBindings
{
    NSMenuItem __unsafe_unretained *menuItem = _driverStateMenuItem;
    NSMenu __unsafe_unretained *menuCopy = menu;
    [virtualScreenController addObserverForKeyPath:@"isFramebufferActive"
                                              task:^(id obj, NSDictionary *change) {
                                                  if ([[change objectForKey: @"new"] boolValue])
                                                  {
                                                      menuItem.title = NSLocalizedString(@"Disable virtual screen", @"");
                                                      
                                                      int i = 1;
                                                      NSMenuItem *separator = [NSMenuItem separatorItem];
                                                      [menuCopy insertItem: separator atIndex:2];
                                                      
                                                      NSMenuItem *menuTitle = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Virtual screen", @"")
                                                                                                         action:nil 
                                                                                                  keyEquivalent:@""];
                                                      [menuTitle setEnabled:NO];
                                                      [menuCopy insertItem: menuTitle atIndex:3];
                                                      
                                                      for (NSString * mode in virtualScreenController.profileNames)
                                                      {
                                                          NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle: mode
                                                                                                               action: @selector(changeMode:) 
                                                                                                        keyEquivalent: @""];
                                                          newMenuItem.tag = i;
                                                          if (i==virtualScreenController.currentMode)
                                                              newMenuItem.state=NSOnState;    
                                                          [menuCopy insertItem: newMenuItem atIndex:3+i];
                                                          i++;
                                                      }
                                                      
                                                      
                                                  }
                                                  else {
                                                      menuItem.title = NSLocalizedString(@"Enable virtual screen", @"");
                                                      int i=2;
                                                      while ([[menuCopy itemAtIndex: i] tag] != -1)
                                                      {
                                                          [menuCopy removeItemAtIndex:i];
                                                      }
                                                  }
                                              }];
    
    NSMenuItem __unsafe_unretained *syphonStateMenuItemCopy = _syphonStateMenuItem;
    NSStatusItem __unsafe_unretained *statusItemCopy = _statusItem;
    [screenCaptureController addObserverForKeyPath:@"capturing"
                                              task:^(id obj, NSDictionary *change) {
                                                  if ([[change objectForKey: @"new"] boolValue])
                                                  {
                                                      syphonStateMenuItemCopy.title = NSLocalizedString(@"Disable Syphon server", @"");
                                                      NSImage *statusImage = [NSImage imageNamed:@"shape_green"];
                                                      [statusItemCopy setImage: statusImage];
                                                      
                                                      
                                                  }
                                                  else {
                                                      syphonStateMenuItemCopy.title = NSLocalizedString(@"Enable Syphon server", @"");
                                                      NSImage *statusImage = [NSImage imageNamed:@"shape_darkgray"];
                                                      [statusItemCopy setImage: statusImage];
                                                      
                                                  }
                                              }];
    

}
#pragma mark - Preferences

- (void) setDefaultPreferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithBool: YES], @"activateVirtualScreenAtStartup",
                          [NSNumber numberWithBool: YES], @"activateShyponServerAtStartup",
                          [NSNumber numberWithInt: 0], @"virtualScreenMode",
                          @"display", @"syphonServerName",                         
                          nil ]; // terminate the list
    [preferences registerDefaults:dict];
}

#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

    // Preferences
    // set default preferences if it is the first time the app is launched
    [self setDefaultPreferences];

    // Driver
    // setup connection with EWProxyFramebuffer virtual device driver 
    bool result =  [virtualScreenController setupConnection];
    if (!result)
        _driverStateMenuItem.title = NSLocalizedString(@"Driver not loaded.",@"");
    self.isDriverLoaded = result;

    
    // UI
    // setup icon in the statusbar and labels bindings
    [self setupStatusItem];
    [self setupMenuItemsDescriptorsBindings];


    // Read preferences and setup virtual device if needed
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

    bool altPressed = [NSEvent modifierFlags] & NSAlternateKeyMask; 
    if ((self.isDriverLoaded) && !(altPressed))
    {
        if ([preferences boolForKey: @"activateVirtualScreenAtStartup"])
        {
            int mode = [preferences integerForKey: @"virtualScreenMode"];
            bool result = [virtualScreenController setVirtualScreenEnabledWithMode: mode 
                                                                     waitUntilDone: YES];
            if ([preferences boolForKey: @"activateShyponServerAtStartup"])
            {
                if (result)
                {
                    // Wait a while to give CoreGraphics time to setup everything.. Workaround for a crash
                    double delayInSeconds = 5.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        [self setSyphonServerEnabled: YES];
                        
                    });
                }

            }
        }
    }
    [preferences stringForKey: @"syphonServerName"];

    
}

- (void) setSyphonServerEnabled: (BOOL) enabled
{
    if (enabled)
    {
        // If you're on a multi-display system and you want to capture a secondary display,
        // you can call CGGetActiveDisplayList() to get the list of all active displays.
        // For this example, we just specify the main display.
        CGDirectDisplayID activeDisplays[10]; 
        uint32_t displayCount;
        CGGetActiveDisplayList(10,
                               activeDisplays, &displayCount);
        
        
        CGDirectDisplayID displayId = activeDisplays[displayCount-1];
        
       // NSLog(@"Active displays are %i\nMain display ID: %i\nActivating syphon server on display with ID: %i", displayCount, kCGDirectMainDisplay, displayId);

        [screenCaptureController startCapturingDisplayID: displayId
                                            syServerName: [[NSUserDefaults standardUserDefaults] stringForKey: @"syphonServerName"]
                                                 context: openGLView.openGLContext ];
    }
    else 
        [screenCaptureController stopCapturing];
}

- (IBAction)toggleVirtualScreen:(id)sender {
        
    [virtualScreenController setVirtualScreenEnabled: !virtualScreenController.isFramebufferActive];
}

- (IBAction)toggleSyphonServer:(id)sender 
{
    [self setSyphonServerEnabled: !screenCaptureController.capturing];       
}

- (IBAction)updateFramebuffer:(id)sender {
    
    [virtualScreenController updateFramebuffer];


    
}

- (IBAction) changeMode:(id)sender
{
    int newMode = [sender tag];

    // if running, stop the syphon server
    bool capturing = screenCaptureController.capturing;
    if (capturing)
        [self setSyphonServerEnabled: NO];

    // switch mode
    bool result=[virtualScreenController setVirtualScreenEnabledWithMode:newMode
                                               waitUntilDone: YES];
    
    if (result)
    {
        
        // workaround! check applicationDidFinishLaunching
        if (capturing) 
        {
            // Wait a while to give CoreGraphics time to setup everything.. Workaround for a crash
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self setSyphonServerEnabled: YES];
                
            });
        }
        
        // save the selected mode in preferences file
        [[NSUserDefaults standardUserDefaults] setInteger: newMode forKey: @"virtualScreenMode"];
        
    }

}

#pragma mark - NSMenuDelegate

- (void)menuWillOpen:(NSMenu *)thismenu
{
    int curMode = virtualScreenController.currentMode;
    for (NSMenuItem *item in thismenu.itemArray)
        [item setState: NSOffState];
    [thismenu itemWithTag: curMode].state = NSOnState;

}
@end
