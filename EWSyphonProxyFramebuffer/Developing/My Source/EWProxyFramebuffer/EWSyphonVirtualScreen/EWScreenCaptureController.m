//
//  EWScreenCaptureController.m
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "EWScreenCaptureController.h"
#import <Syphon/Syphon.h>



@interface EWScreenCaptureController ()  {
    CVOpenGLTextureCacheRef _textureCache;
}


@property (readwrite) bool capturing;
@property (readwrite, copy) NSString *_serverName;
@property (readwrite, strong) NSOpenGLContext *openGLContext;
@property (readwrite, strong) NSOpenGLPixelFormat *openGLPixelFormat;
@property (readwrite, strong) SyphonServer *syphonServer;
@property (readwrite) CGDirectDisplayID displayID;
@end


@implementation EWScreenCaptureController
@synthesize capturing;
@synthesize _serverName;
@synthesize openGLContext = _openGLContext, openGLPixelFormat = _openGLPixelFormat;
@synthesize syphonServer = _syphonServer;
@synthesize displayID = _displayID;

#pragma mark - Initialization and dealloc

- (bool)initOpenGLContextWithSharedContext: (NSOpenGLContext*)sharedContext error: (NSError **)error {
    
    NSOpenGLPixelFormatAttribute	attributes[] = {
		NSOpenGLPFAPixelBuffer,
		//NSOpenGLPFANoRecovery,
		//kCGLPFADoubleBuffer,
		//NSOpenGLPFAAccelerated,
		NSOpenGLPFADepthSize, 32,
		(NSOpenGLPixelFormatAttribute) 0
	};
    
    /*NSOpenGLPixelFormatAttribute    attributes[] = {
        NSOpenGLPFAPixelBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADepthSize, 32,
        (NSOpenGLPixelFormatAttribute) 0
    };*/
    
	NSOpenGLPixelFormat*	newPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] ;
    
	NSOpenGLContext *newOpenGLContext = [[NSOpenGLContext alloc] initWithFormat: newPixelFormat 
                                                                   shareContext: sharedContext] ;
	if(newOpenGLContext == nil) {
		return false;
	}
	
	_openGLContext = newOpenGLContext ;	
	_openGLPixelFormat = newPixelFormat;
	
    
	return true;
	
}

#pragma mark - To override


-(void)startCapturingDisplayID: (CGDirectDisplayID)displayId
                  syServerName: (NSString *)syServerName
                       context: (NSOpenGLContext *)openGLContext

{
    if ([self initOpenGLContextWithSharedContext: openGLContext
                                       error: nil])
    {
        // init Syphon server
        self._serverName = syServerName;
        self.syphonServer = [[SyphonServer alloc] initWithName:	 syServerName
                                                       context:	 openGLContext.CGLContextObj
                                                       options:	 nil]; 
        self.displayID = displayId;
        self.capturing = YES;
        
    }
    

}

- (void) stopCapturing
{
 
    [_syphonServer stop];
    self.capturing = NO;

    _openGLContext = nil;
    _openGLPixelFormat = nil;
    _syphonServer = nil;

}


@end
