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
