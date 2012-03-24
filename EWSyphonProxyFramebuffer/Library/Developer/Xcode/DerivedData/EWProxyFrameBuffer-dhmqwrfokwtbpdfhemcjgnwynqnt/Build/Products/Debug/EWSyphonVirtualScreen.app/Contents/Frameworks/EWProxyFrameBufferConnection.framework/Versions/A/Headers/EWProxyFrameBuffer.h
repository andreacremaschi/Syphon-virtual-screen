/*
 *  PSPScreenShared.h
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef PSPSCREENSHARED_H__
#define PSPSCREENSHARED_H__

//this is our dispatch pointer. It contains an element for each callable function
enum {
	kEWProxyStartFramebuffer,
	kEWProxyStopFramebuffer,
	kEWProxyCheckFramebufferState,
	kEWProxyUpdateMemoy,
	kEWProxyGetModeCount,
	kEWProxyGetModeInfo,
	kEWProxyGetCursorState,
	kEWProxyGetCursorResolution,
	kEWProxyEnableCursorEvents,
	kEWProxyDisableCursorEvents,
	kNumberOfMethods
};

//this enum is used to tell about the event origin.
enum {
	kEWProxyCursorStateChanged,
	kEWProxyCursorImageChanged
};

//This structure is used to transport mode information from kernel to user space.
//these information are stored in the drivers plist
typedef struct {
	char name[32];
	unsigned int width;
	unsigned int height;
} EWProxyFramebufferModeInfo;

//we're matching against class name of our driver
#define pspdriverclass "info_ennowelbers_proxyframebuffer_driver"
//these are used as return values in state functions
#define FBufEnabled 1
#define FBufDisabled 0

io_service_t FindEWProxyFramebufferDriver(void);
int EWProxyFramebufferDriverCheckFramebufferState(io_connect_t connect);
void EWProxyFramebufferDriverEnableFramebuffer(io_connect_t connect, int mode);
void EWProxyFramebufferDriverDisableFramebuffer(io_connect_t connect);
unsigned char *EWProxyFramebufferDriverMapCursor(io_connect_t connect, unsigned int *size, int *width, int *height);
void EWProxyFramebufferDriverUnmapCursor(io_connect_t connect, unsigned char *buf);
unsigned char *EWProxyFramebufferDriverMapFramebuffer(io_connect_t connect, unsigned int *size);
void EWProxyFramebufferDriverUnmapFramebuffer(io_connect_t connect, unsigned char *buf);
int EWProxyFramebufferDriverUpdateMemory(io_connect_t connect);
int EWProxyFramebufferDriverGetModeCount(io_connect_t connect);
void EWProxyFramebufferDriverGetCursorState(io_connect_t connect, int *x, int *y, bool *visible);
kern_return_t EWProxyFramebufferDriverGetModeInfo(io_connect_t connect, int mode, EWProxyFramebufferModeInfo *info);
bool EWProxyFramebufferDriverEnableCursorEvents(io_connect_t connect, mach_port_t recallport, void * callback, void *reference);
bool EWProxyFramebufferDriverDisableCursorEvents(io_connect_t connect);

#endif