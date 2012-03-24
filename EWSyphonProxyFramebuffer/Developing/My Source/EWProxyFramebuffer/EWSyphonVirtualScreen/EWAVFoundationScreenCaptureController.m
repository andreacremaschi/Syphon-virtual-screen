//
//  EWScreenCaptureController.m
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "EWAVFoundationScreenCaptureController.h"
#import <Syphon/Syphon.h>



@interface EWAVFoundationScreenCaptureController () <AVCaptureVideoDataOutputSampleBufferDelegate> {
    CVOpenGLTextureCacheRef _textureCache;
    AVCaptureSession *mSession;
    AVCaptureVideoDataOutput *mDataOutput;
}


@property (readwrite) bool capturing;
@property (readwrite, copy) NSString *_serverName;
@property (readwrite, strong) NSOpenGLContext *_openGLContext;
@property (readwrite, strong) NSOpenGLPixelFormat *_openGLPixelFormat;
@property (readwrite, strong) SyphonServer *_syphonServer;
@end


@implementation EWAVFoundationScreenCaptureController
@synthesize capturing;

#pragma mark - Initialization and dealloc

-(void)dealloc
{
    if ([mSession isRunning])
        [mSession stopRunning];
    mSession = nil;
    mDataOutput = nil;
}


#pragma mark - AVFoundation stuff

-(void)startCapturingDisplayID: (CGDirectDisplayID)displayId
                  syServerName: (NSString *)syServerName
                       context: (NSOpenGLContext *)openGLContext

{
    [super startCapturingDisplayID: displayId
                      syServerName: syServerName 
                           context: openGLContext];
    
    // Create a capture session
    mSession = [[AVCaptureSession alloc] init];
    
    // Set the session preset as you wish
    mSession.sessionPreset = AVCaptureSessionPresetMedium;

    // Create a ScreenInput with the display and add it to the session
    AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:displayId] ;
    if (!input) {
        mSession = nil;
        return;
    }
    if ([mSession canAddInput:input])
        [mSession addInput:input];
    
    // Create a MovieFileOutput and add it to the session
    dispatch_queue_t queue = dispatch_queue_create("virtualScreenCaptureQueue", NULL);
    mDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [mDataOutput setSampleBufferDelegate: self
                                   queue: queue];
    dispatch_release(queue);

    // Specify the pixel format
    mDataOutput.videoSettings = 
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];

    // If you wish to cap the frame rate to a known value, such as 15 fps, set 
    // minFrameDuration.
    input.minFrameDuration = CMTimeMake(1, 15);

    if ([mSession canAddOutput:mDataOutput])
        [mSession addOutput:mDataOutput];
  
    // Start running the session
    [mSession startRunning];

    
}

- (void) stopCapturing
{
    
    if ([mSession isRunning])
        [mSession stopRunning];

    mSession = nil;
    mDataOutput = nil;  

    [super stopCapturing];
}

// AVCaptureFileOutputRecordingDelegate methods
-(void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
      fromConnection:(AVCaptureConnection *)connection
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0); 
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
   
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    
    
    CGLContextObj cgl_ctx = [self.openGLContext CGLContextObj];
    CGLPixelFormatObj pixelFormat = self.openGLPixelFormat.CGLPixelFormatObj;
    //CGLLockContext(cgl_ctx);
    
    CVOpenGLTextureRef textureOut;
    CVReturn theError ;
    
    if (!_textureCache)    
    {
        theError= CVOpenGLTextureCacheCreate(NULL, 0, 
                                             cgl_ctx, 
                                             pixelFormat, 
                                             0, &_textureCache);
        if (theError != kCVReturnSuccess)
        {
            //TODO: error handling
        }
        
    }
    theError= CVOpenGLTextureCacheCreateTextureFromImage ( NULL, 
                                                          _textureCache, 
                                                          imageBuffer, 
                                                          NULL, 
                                                          &textureOut );
    if (theError != kCVReturnSuccess)
    {
        //TODO: error handling
    }
    
    GLenum target = CVOpenGLTextureGetTarget(textureOut);
    GLint name = CVOpenGLTextureGetName(textureOut);     
    
    
    // publish our frame to our server. 
    [self.syphonServer publishFrameTexture: name
                         textureTarget: target
                           imageRegion: NSMakeRect(0,0, width, height)
                     textureDimensions: NSMakeSize(width, height)
                               flipped: NO];
    
    CVOpenGLTextureRelease(textureOut);  
    CVOpenGLTextureCacheFlush(_textureCache, 0);

    //CGLUnlockContext(cgl_ctx);
    
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
   // CGContextRelease(context); 
    CGColorSpaceRelease(colorSpace);
    
    return;
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection  
{
    
}

@end
