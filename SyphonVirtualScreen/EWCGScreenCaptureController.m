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

#import "EWCGScreenCaptureController.h"
#import <OpenGL/CGLMacro.h>
#import <Syphon/Syphon.h>

@interface EWCGScreenCaptureController () {
    bool dropNext;
    NSRunLoop *_timerRunLoop;
    NSThread *_timerThread;

    GLuint _textureName;
    long _width, _height;
}
@property (strong) NSTimer *captureTimer;
- (void)timerFire:(NSTimer*)theTimer;
- (void) stopCaptureTimer;

@end

@implementation EWCGScreenCaptureController
@synthesize captureTimer;

- (void)startCapturingDisplayID: (CGDirectDisplayID)displayId 
                   syServerName: (NSString *)syServerName 
                        context: (NSOpenGLContext *)openGLContext
{
    [super startCapturingDisplayID:displayId
                      syServerName:syServerName
                           context:openGLContext];

    CGDisplayModeRef displayModeRef = CGDisplayCopyDisplayMode(displayId);
    _width = CGDisplayModeGetWidth(displayModeRef); 
    _height = CGDisplayModeGetHeight(displayModeRef);
    
    // generate a texture and clear it
    CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
    glGenTextures(1, &_textureName);
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureName);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _textureName);

    
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

    [super stopCapturing];


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
            
            //            CVOpenGLTextureCacheFlush(_textureCache, 0);
            
        }
    }
}

#pragma mark - Timer tick

- (void) _timerTick
{ 
    @autoreleasepool {
        
        if ([self.syphonServer hasClients])
        {
            
            CGImageRef myImageRef =  CGDisplayCreateImage(self.displayID);
            
            CGLContextObj cgl_ctx = self.openGLContext.CGLContextObj;
            
            size_t width = CGImageGetWidth(myImageRef);
            size_t height = CGImageGetHeight(myImageRef);
            
            CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(myImageRef));
            UInt8 *myData = (UInt8 *)CFDataGetBytePtr(data);
            
            glPixelStorei(GL_UNPACK_ROW_LENGTH, width);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            
            glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
                            GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height,
                         0, GL_BGRA_EXT, GL_UNSIGNED_INT_8_8_8_8_REV, myData);
           
            CFRelease(data);
            CGImageRelease(myImageRef);      
            
            // publish our frame to our server. 
            [self.syphonServer publishFrameTexture: _textureName
                                     textureTarget: GL_TEXTURE_RECTANGLE_ARB
                                       imageRegion: NSMakeRect(0,0, width, height)
                                 textureDimensions: NSMakeSize(width, height)
                                           flipped: YES];
        }
        
    }
}



@end
