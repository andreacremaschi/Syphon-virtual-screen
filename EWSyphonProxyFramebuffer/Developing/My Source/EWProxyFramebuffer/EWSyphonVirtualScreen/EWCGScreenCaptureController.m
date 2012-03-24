//
//  EWCGScreenCaptureController.m
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 22/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
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
