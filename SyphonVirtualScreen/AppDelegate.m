//
// Copyright (c) 2012, Andrea Cremaschi
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// * Neither the name of the copyright holder nor the
// names of its contributors may be used to endorse or promote products
// derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL ENNO WELBERS BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "AppDelegate.h"
#import "EWScreenCaptureController.h"
#import "EWVirtualScreenController.h"

#import "NSObject+BlockObservation.h"

#import <EWProxyFrameBuffer/EWProxyFrameBuffer.h>


@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@end


@implementation AppDelegate

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
    
    if (self.isDriverLoaded)
    {    
        //[_statusItem setTitle:@"Status"];
        NSImage *statusImage = [NSImage imageNamed:@"shape_darkgray"];
        [_statusItem setImage: statusImage];
        [_statusItem setHighlightMode:YES];
    }
    else {
        _driverStateMenuItem.title = NSLocalizedString(@"Driver not loaded.",@"");
        NSImage *statusImage = [NSImage imageNamed:@"shape_red"];
        [_statusItem setImage: statusImage];
    }
    [_statusItem setMenu:menu];
        
}

- (void) setupMenuItemsDescriptorsBindings
{
    NSMenuItem __unsafe_unretained *menuItem = _driverStateMenuItem;
    NSMenu __unsafe_unretained *menuCopy = menu;

    [virtualScreenController addObserverForKeyPath:@"isFramebufferActive"
                                              task:^(id obj, NSDictionary *change) {
                                           EWVirtualScreenController  *vsController = (EWVirtualScreenController*)obj;
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
                                                      
                                                      for (NSString * mode in vsController.profileNames)
                                                      {
                                                          NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle: mode
                                                                                                               action: @selector(changeMode:) 
                                                                                                        keyEquivalent: @""];
                                                          newMenuItem.tag = i;
                                                          if (i==vsController.currentMode)
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
            NSInteger mode = [preferences integerForKey: @"virtualScreenMode"];
            bool result = [virtualScreenController setVirtualScreenEnabledWithMode: mode 
                                                                     waitUntilDone: YES];
            if ([preferences boolForKey: @"activateShyponServerAtStartup"])
            {
                if (result)
                {
                    // Wait a while to give CoreGraphics time to setup everything.. Workaround for a crash
                    double delayInSeconds = 3.0;
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
    
        [screenCaptureController startCapturingEWProxyFrameBuffer: virtualScreenController
                                                     syServerName: [[NSUserDefaults standardUserDefaults] stringForKey: @"syphonServerName"]
                                                          context: nil]; //openGLView.openGLContext ];         
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


- (IBAction) changeMode:(id)sender
{
    NSInteger newMode = [sender tag];

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
