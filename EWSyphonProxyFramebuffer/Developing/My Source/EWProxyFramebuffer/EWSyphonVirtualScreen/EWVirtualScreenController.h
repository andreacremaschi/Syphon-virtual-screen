//
//  EWVirtualScreenController.h
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^completionBlock)(void);

@interface EWVirtualScreenController : NSObject

@property (unsafe_unretained, readonly) NSArray *profiles;
@property (unsafe_unretained, readonly) NSArray *profileNames;
@property (readonly) int currentMode;

@property (readonly) bool isFramebufferActive;

- (BOOL) setupConnection;
- (void) setVirtualScreenEnabled: (BOOL) enable;
- (bool) setVirtualScreenEnabledWithMode: (int) mode waitUntilDone: (BOOL) waitUntilDone;
- (void) switchToMode: (int) mode;
- (bool) updateFramebuffer;

@end
