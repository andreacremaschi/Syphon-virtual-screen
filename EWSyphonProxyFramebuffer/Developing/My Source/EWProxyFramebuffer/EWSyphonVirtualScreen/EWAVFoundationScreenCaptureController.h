//
//  EWScreenCaptureController.h
//  EWProxyFrameBuffer
//
//  Created by Andrea Cremaschi on 21/03/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "EWScreenCaptureController.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface EWAVFoundationScreenCaptureController : EWScreenCaptureController  <AVCaptureVideoDataOutputSampleBufferDelegate>

@end
