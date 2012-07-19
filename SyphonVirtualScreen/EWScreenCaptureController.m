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
#import "EWVirtualScreenController.h"
#import <Syphon/Syphon.h>

#include <EWProxyFrameBufferConnection/EWProxyFrameBuffer.h>

#import <OpenGL/CGLMacro.h>

@interface EWScreenCaptureController ()   {
    CVOpenGLTextureCacheRef _textureCache;
    
    bool dropNext;
    NSRunLoop *_timerRunLoop;
    NSThread *_timerThread;
    
    GLuint _textureName;
    long _width, _height;
}
@property (strong) NSTimer *captureTimer;
- (void)timerFire:(NSTimer*)theTimer;
- (void) stopCaptureTimer;


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
@synthesize captureTimer;
@synthesize virtualScreenController = _virtualScreenController;

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

-(void)startCapturingEWProxyFrameBuffer:(EWVirtualScreenController *)vsController 
                           syServerName:(NSString *)syServerName 
                                context:(NSOpenGLContext *)openGLContext

{
    if ([self initOpenGLContextWithSharedContext: openGLContext
                                           error: nil])
    {
        // init Syphon server
        self._serverName = syServerName;
        self.syphonServer = [[SyphonServer alloc] initWithName:	 syServerName
                                                       context:	 openGLContext.CGLContextObj
                                                       options:	 nil]; 
        _virtualScreenController= vsController;
        self.capturing = YES;
        
    }
    
    // Kick off a new Thread
    [NSThread detachNewThreadSelector:@selector(createTimerRunLoop) 
                             toTarget:self 
                           withObject:nil];
}

-(void)stopCapturing    
{
    [self stopCaptureTimer];
    
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    glDeleteTextures(1, &_textureName);
    
    [_syphonServer stop];
    self.capturing = NO;
    
    _openGLContext = nil;
    _openGLPixelFormat = nil;
    _syphonServer = nil;    
    
}

- (void) createTimerRunLoop
{
    _timerRunLoop = [NSRunLoop currentRunLoop];
    _timerThread = [NSThread currentThread];
    
    [self createTimer];
    
    while (captureTimer && [_timerRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
}

- (void) createTimer{
    @autoreleasepool {
        
        dropNext=false;
        
        // Create a time for the thread
        captureTimer = [NSTimer timerWithTimeInterval: 1.0/ 60.0
                                               target: self 
                                             selector: @selector(timerFire:)
                                             userInfo: nil 
                                              repeats: YES];
        
        // Add the timer to the run loop
        [_timerRunLoop addTimer: captureTimer
                        forMode: NSDefaultRunLoopMode];
        
        
    }        
}

- (void) stopCaptureTimer
{
    @synchronized (captureTimer)
    {
        [captureTimer invalidate];
        captureTimer=nil;
    }
}


- (void)timerFire:(NSTimer*)theTimer
{
    
    
    if (dropNext) 
    {
        // NSLog(@"Drop a frame!");
        return;   
    }
    @synchronized(captureTimer)
    {
        
        if ((!captureTimer.isValid) )
            return;
        
        @autoreleasepool {
            dropNext=YES;
            [self _timerTick];
            dropNext=NO;
                        
        }
    }
}

#pragma mark - Timer tick

- (void) _timerTick
{ 
    if ([self.syphonServer hasClients])
    {
        
        if ([self.virtualScreenController updateFramebuffer])
        {
            void *driverBuf = (void *)self.virtualScreenController.driverBuffer;
            
            CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
            EWProxyFramebufferModeInfo *info = [self.virtualScreenController getCurrentModeInfo];
            
            size_t width = info->width;
            size_t height = info->height;
            
            if ((width != _width) || (height != _height))
            {
                _width = width;
                _height = height;
                
                if (_textureName)
                    glDeleteTextures(1, &_textureName);
                
                // Enable Apple Client storage
                glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
                
                // generate a texture and clear it
                CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
                glGenTextures(1, &_textureName);
                glEnable(GL_TEXTURE_RECTANGLE_EXT);
                
                // Eliminate a data copy by the OpenGL driver using the Apple texture range extension along with the rectangle texture extension
                // This specifies an area of memory to be mapped for all the textures. It is useful for tiled or multiple textures in contiguous memory.
                glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, width * height * 4, driverBuf);
                
                
                glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
                glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);   
                glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
                

            }
            
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, _width+8);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_CACHED_APPLE);
            
            glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, driverBuf);

            glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);            
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);

            
            
            // publish our frame to our server. 
            [self.syphonServer publishFrameTexture: _textureName
                                     textureTarget: GL_TEXTURE_RECTANGLE_EXT
                                       imageRegion: NSMakeRect(0,0, width, height)
                                 textureDimensions: NSMakeSize(width, height)
                                           flipped: YES];

        }
    }
}


@end
