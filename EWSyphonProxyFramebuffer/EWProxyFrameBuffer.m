/*
 *  PSPScreenShared.cpp
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */
#include <IOKit/IOKitLib.h>
#include "EWProxyFrameBuffer.h"

//This function helps finding the driver
io_service_t FindEWProxyFramebufferDriver(void)
{
	return IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(pspdriverclass));
}

#pragma mark memory mapping functions

unsigned char *EWProxyFramebufferDriverMapCursor(io_connect_t connect, unsigned int *size, int *width, int *height)
{
#ifdef __LP64__
	mach_vm_address_t address=0;
	mach_vm_size_t vmsize=0;
#else
	vm_address_t address=0;
	vm_size_t vmsize=0;
#endif
	IOConnectMapMemory(connect, 1, mach_task_self(), &address, &vmsize, kIOMapAnywhere);
	*size=vmsize;
	
	uint64_t buf[]={0,0};
	uint32_t cnt=2;
	IOConnectCallScalarMethod(connect, kEWProxyGetCursorResolution, NULL, 0, buf, &cnt);
	*width=(int)buf[0];
	*height=(int)buf[1];
	return (unsigned char*)address;
}

void EWProxyFramebufferDriverUnmapCursor(io_connect_t connect, unsigned char *buf)
{
#ifdef __LP64__
	mach_vm_address_t address=(mach_vm_address_t)buf;
#else
	vm_address_t address=(vm_address_t)buf;
#endif
	IOConnectUnmapMemory(connect, 1, mach_task_self(), address);
}

unsigned char *EWProxyFramebufferDriverMapFramebuffer(io_connect_t connect, unsigned int *size)
{
#ifdef __LP64__
	mach_vm_address_t address=0;
	mach_vm_size_t vmsize=0;
#else
	vm_address_t address=0;
	vm_size_t vmsize=0;
#endif
	IOConnectMapMemory(connect, 0, mach_task_self(), &address, &vmsize, kIOMapAnywhere);
	*size=vmsize;
	return (unsigned char*)address;
}

void EWProxyFramebufferDriverUnmapFramebuffer(io_connect_t connect, unsigned char *buf)
{
#ifdef __LP64__
	mach_vm_address_t address=(mach_vm_address_t)buf;
#else
	vm_address_t address=(vm_address_t)buf;
#endif
	IOConnectUnmapMemory(connect, 0, mach_task_self(), address);
}

#pragma mark user->kernel call chain functions

int EWProxyFramebufferDriverCheckFramebufferState(io_connect_t connect)
{
	return (int)IOConnectCallScalarMethod(connect, kEWProxyCheckFramebufferState, NULL, 0, NULL, NULL);
}

void EWProxyFramebufferDriverEnableFramebuffer(io_connect_t connect, int mode)
{
	uint64_t buf[1]={mode};
	IOConnectCallScalarMethod(connect, kEWProxyStartFramebuffer, buf, 1, NULL, NULL);
}

void EWProxyFramebufferDriverDisableFramebuffer(io_connect_t connect)
{
	IOConnectCallScalarMethod(connect, kEWProxyStopFramebuffer, NULL, 0, NULL, NULL);
	
}

int EWProxyFramebufferDriverUpdateMemory(io_connect_t connect)
{
	kern_return_t ret=IOConnectCallScalarMethod(connect, kEWProxyUpdateMemoy, NULL, 0, NULL, 0);
	return ret;
}

int EWProxyFramebufferDriverGetModeCount(io_connect_t connect)
{
	kern_return_t ret=IOConnectCallScalarMethod(connect, kEWProxyGetModeCount, NULL, 0, NULL, 0);
	return ret;
}

kern_return_t EWProxyFramebufferDriverGetModeInfo(io_connect_t connect, int mode, EWProxyFramebufferModeInfo *info)
{
	uint64_t buf=mode;
	size_t size=sizeof(*info);
	kern_return_t ret=IOConnectCallMethod(connect, kEWProxyGetModeInfo, &buf, 1, NULL, 0, NULL, NULL, (void*)info, &size);
	return ret;
}

void EWProxyFramebufferDriverGetCursorState(io_connect_t connect, int *x, int *y, bool *visible)
{
	uint64_t buf[]={0,0,0};
	unsigned int cnt=3;
	IOConnectCallScalarMethod(connect, kEWProxyGetCursorState, NULL, 0, buf, &cnt);
	*x=(int)buf[0];
	*y=(int)buf[1];
	*visible=(bool)buf[2];
}

#pragma mark event registration functions

bool EWProxyFramebufferDriverEnableCursorEvents(io_connect_t connect, mach_port_t recallport, void *callback, void *reference)
{
	IOConnectSetNotificationPort(connect, 0, recallport, 0);
#ifdef __LP64__
	uint64_t buf[]={(uint64_t)(mach_vm_address_t)callback, (uint64_t)(io_user_reference_t)reference};
#else
	uint64_t buf[]={(uint64_t)(vm_address_t)callback, (uint64_t)(vm_address_t)reference};
#endif
	kern_return_t ret=IOConnectCallScalarMethod(connect, kEWProxyEnableCursorEvents, buf, 2, NULL, NULL);
	if(ret!=kIOReturnSuccess)
		return false;
	return true;
}

bool EWProxyFramebufferDriverDisableCursorEvents(io_connect_t connect)
{
	return IOConnectCallScalarMethod(connect, kEWProxyDisableCursorEvents, NULL, 0, NULL, NULL)==kIOReturnSuccess;
}
