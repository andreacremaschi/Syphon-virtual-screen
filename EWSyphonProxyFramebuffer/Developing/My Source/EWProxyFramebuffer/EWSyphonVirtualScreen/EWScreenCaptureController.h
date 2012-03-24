//
//  EWScreenCaptureController.h
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SyphonServer;
@interface EWScreenCaptureController : NSObject

@property (readonly, strong) NSOpenGLContext *openGLContext;
@property (readonly, strong) NSOpenGLPixelFormat *openGLPixelFormat;
@property (readonly, strong) SyphonServer *syphonServer;
@property (readonly) bool capturing;
@property (readonly) CGDirectDisplayID displayID;

-(void) startCapturingDisplayID: (CGDirectDisplayID)displayId
                   syServerName: (NSString *)syServerName
                        context: (NSOpenGLContext *)openGLContext;
- (void) stopCapturing;

@end
