//
//  UIMainDialog.m
//  PSPScreenDriverClient
//
//  Created by Enno Welbers on 27.02.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include <IOKit/IOKitLib.h>
#include <EWSyphonProxyFrameBufferConnection/EWProxyFrameBuffer.h>
#import "UIMainDialog.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <netdb.h>
#include <IOKit/IOKitLib.h>
#include <mach/mach_time.h>
//#include "huffman.h"

@implementation UIMainDialog
@synthesize imgState,driverState,ProfileNames,selectedProfile,bufferOn;


- (IBAction) fetchImage:(id)sender
{
	//tell driver to update buffer mapped to client memory
	int ret=EWProxyFramebufferDriverUpdateMemory(connect);
	//NSLog(@"%x",ret);
	EWProxyFramebufferModeInfo *info=[self getCurrentModeInfo];
	//copy into nsdata object
	NSData *image=[[NSData alloc] initWithBytes:driverbuf length:info->width*info->height*3];
	//encapsulate into cg data provider
	CGDataProviderRef dataprovider=CGDataProviderCreateWithCFData((CFDataRef)image);
	//create cg image from provider
	CGImageRef cgimg=CGImageCreate(info->width, info->height, 8, 32, info->width*4, CGColorSpaceCreateDeviceRGB(), (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host), dataprovider, NULL, NO, kCGRenderingIntentDefault);
	//create bitmapimagerepresentation
	NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithCGImage:cgimg];
	//and stuff it into an nsimage
	NSImage *img=[[NSImage alloc] init];
	[img addRepresentation:rep];
	[imgView setImage:img];
}

- (EWProxyFramebufferModeInfo*) getCurrentModeInfo
{
	NSData *data=[Profiles objectAtIndex:[self.selectedProfile firstIndex]];
	return (EWProxyFramebufferModeInfo*)[data bytes];
}

- (int) getMode {
	int mode=[self.selectedProfile firstIndex];
	mode++;
	return mode;
}

- (IBAction) SwitchDriver:(id)sender
{
	//check current state.
	int state=EWProxyFramebufferDriverCheckFramebufferState(connect);
	if(state!=0)
	{
		//framebuffer is on, disable it. unmap framebuffer and disable it.
		EWProxyFramebufferDriverUnmapFramebuffer(connect, driverbuf);
		EWProxyFramebufferDriverDisableFramebuffer(connect);
		self.driverState=@"FB OFF";
		self.bufferOn=NO;
	}
	else
	{
		int mode;
		mode = [self getMode];
		//enable with selected mode
		EWProxyFramebufferDriverEnableFramebuffer(connect, mode);
		self.bufferOn=YES;
		unsigned int size;
		//map memory
		driverbuf=EWProxyFramebufferDriverMapFramebuffer(connect, &size);
		self.driverState=@"FB ON";
	}
}

- (void)awakeFromNib
{
	self.driverState=@"UNKNOWN";
	//check for driver. if found, set everything up.
	service=FindEWProxyFramebufferDriver();
	if(service==IO_OBJECT_NULL)
	{
		self.driverState=@"Nicht geladen.";
	}
	else
	{
		//establish connection.
		//this call instantiates our user client class in kernel code and attaches it to
		//the IOService in question
		if(IOServiceOpen(service, mach_task_self(), 0, &connect)==kIOReturnSuccess)
		{
			//read the driver configuration and set up internal classes
			int cnt=EWProxyFramebufferDriverGetModeCount(connect);
			ProfileNames=[[NSMutableArray alloc] init];
			Profiles=[[NSMutableArray alloc] init];
			[self willChangeValueForKey:@"ProfileNames"];
			EWProxyFramebufferModeInfo data;
			for(int i=1;i<=cnt;i++)
			{
				EWProxyFramebufferDriverGetModeInfo(connect, i, &data);
				[ProfileNames addObject:[NSString stringWithCString:data.name encoding:NSASCIIStringEncoding]];
				[Profiles addObject:[NSData dataWithBytes:&data length:sizeof(data)]];
			}
			[self didChangeValueForKey:@"ProfileNames"];
			int state=EWProxyFramebufferDriverCheckFramebufferState(connect);
			if(state!=0)
			{
				self.bufferOn=YES;
				self.driverState=@"FB IN USE";
			}
			else
			{
				self.bufferOn=NO;
				self.driverState=@"FB OFF";
			}
			//create a notification port and register it in our runloop.
			//this is nessecary for the cursor change events.
			//we can ask the notificationport for a mach_port which is then used in registerEvent functions
			//however we're not implementing them yet.
			//TODO
			IONotificationPortRef notifyPort=IONotificationPortCreate(kIOMasterPortDefault);
			CFRunLoopSourceRef rlsource=IONotificationPortGetRunLoopSource(notifyPort);
			CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], rlsource, kCFRunLoopDefaultMode);
		}
		else
		{
			self.driverState=@"Öffnen fehlgeschlagen.";
		}
	}
}


-(CGImageRef)getCursor
{
	unsigned int size;
	int width, height;
	//map the hardwarecursor memory into user space
	unsigned char *buf=EWProxyFramebufferDriverMapCursor(connect, &size, &width, &height);
	//same procedure: pointer->nsdata->cgadatprovider->cgimage
	NSData *image=[NSData dataWithBytes:buf length:size];
	CGDataProviderRef provider=CGDataProviderCreateWithCFData((CFDataRef)image);
	CGImageRef cgimg=CGImageCreate(width, height, 8, 32, width*4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaLast, provider, NULL, NO, kCGRenderingIntentDefault);
	//unmap the memory again.
	EWProxyFramebufferDriverUnmapCursor(connect, buf);
	CFRelease(provider);
	return cgimg;
}

@end
