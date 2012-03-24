/*
 *  PSPScreenClient.h
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */
#ifndef EWPROXYFRAMEBUFFERCLIENT_H__
#define EWPROXYFRAMEBUFFERCLIENT_H__

#include <IOKit/IOService.h>
#include <IOKit/IOUserClient.h>
#include "EWProxyFrameBufferDriver.h"
#include "EWProxyFrameBuffer.h"

/*
 How does an IOKit driver talk to user space?
 You define a set of functions (the descriptor is an int, essentially), and define a user client class
 containing these functions.
 The call comes in through an externalArgument call which then calls static methods which in turn call
 class methods which then do the work.
 Besides, you can map kernel memory into user space and register events.
 The function list is provided to kernel using a dispatch table
 It took me a while to get this straight, however the high-level-feeling of this communication is quite cool.
 Why static methods? why not calling directly the class methods? Static methods have defined adresses we can use
 in our dispatch table. That way the dispatcher Function (externalArgument) get's a lot simpler.
 the con is a lot copy'n'paste-code
 */
class info_ennowelbers_proxyframebuffer_client: public IOUserClient
{
	OSDeclareDefaultStructors(info_ennowelbers_proxyframebuffer_client)
protected:
	info_ennowelbers_proxyframebuffer_driver *fProvider;
	task_t fTask;
	static const IOExternalMethodDispatch sMethods[kNumberOfMethods];
	bool owningFB;
	bool eventEnabled;
	mach_port_t eventPort;
#ifdef __LP64__
    OSAsyncReference64 eventFunction;
#else
	OSAsyncReference eventFunction;
#endif
public:
	//virtual void stop(IOService *provider);
	virtual bool start(IOService *provider);
	
	virtual bool initWithTask(task_t owningTask, void* secuirtyToken, UInt32 type, OSDictionary * properties);
	
	virtual IOReturn clientClose(void);
	virtual IOReturn clientDied(void);
	virtual IOReturn registerNotificationPort(mach_port_t port, UInt32 type, UInt32 refCon );

	//virtual bool willTerminate(IOService* provider, IOOptionBits options);
	//virtual bool didTerminate(IOService* provider, IOOptionBits options, bool *defer);
	
	//virtual bool terminate(IOOptionBits options=0);
	//virtual bool finalize(IOOptionBits options);
	virtual void FireCursorStateChanged();
	virtual void FireCursorImageChanged();
protected:
	virtual IOReturn externalMethod(uint32_t selector, IOExternalMethodArguments * arguments, IOExternalMethodDispatch *dispatch, OSObject*target, void* reference);
	
	static IOReturn sStartFramebuffer(info_ennowelbers_proxyframebuffer_client* target, void* reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn StartFramebuffer(int mode);
	
	static IOReturn sStopFramebuffer(info_ennowelbers_proxyframebuffer_client* target, void*reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn StopFramebuffer(void);
	
	static IOReturn sCheckFramebufferState(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn CheckFramebufferState(void);
		
	static IOReturn sUpdateMemory(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn UpdateMemory(void);
	
	static IOReturn sGetModeCount(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn GetModeCount(void);
	
	static IOReturn sGetModeInfo(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn GetModeInfo(int mode, EWProxyFramebufferModeInfo *info);
	
	static IOReturn sGetCursorState(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn GetCursorState(int *x, int *y, bool *visible);
	
	static IOReturn sGetCursorResolution(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn GetCursorResolution(int *width, int *height);
	
	static IOReturn sEnableCursorEvents(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
#ifdef __LP64__
	virtual IOReturn EnableCursorEvents(mach_vm_address_t call, io_user_reference_t reference);
#else
	virtual IOReturn EnableCursorEvents(void *call, void *reference);
#endif
	
	static IOReturn sDisableCursorEvents(info_ennowelbers_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments);
	
	virtual IOReturn DisableCursorEvents();
	
	virtual IOReturn clientMemoryForType( UInt32 type, IOOptionBits * options, IOMemoryDescriptor ** memory );
};

#endif