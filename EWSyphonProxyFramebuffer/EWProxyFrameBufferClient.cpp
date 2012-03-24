/*
 *  PSPScreenClient.cpp
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */
#include <IOKit/IOLib.h>
#include <IOKit/IOKitKeys.h>
#include <libkern/OSByteOrder.h>
#include "EWProxyFrameBufferClient.h"

#include "EWProxyFrameBufferFBuffer.h"

#define super IOUserClient

OSDefineMetaClassAndStructors(info_ennowelbers_syphon_proxyframebuffer_client, IOUserClient)

#pragma mark Dispatch table
const IOExternalMethodDispatch info_ennowelbers_syphon_proxyframebuffer_client::sMethods[kNumberOfMethods] = {
{
(IOExternalMethodAction) &info_ennowelbers_syphon_proxyframebuffer_client::sStartFramebuffer,//Action
1,//number of scalar inputs
0,//struct input size
0,//number of scalar outputs
0,//struct output size
},
{
(IOExternalMethodAction) &info_ennowelbers_syphon_proxyframebuffer_client::sStopFramebuffer,
0,
0,
0,
0,
},
{
(IOExternalMethodAction) &info_ennowelbers_syphon_proxyframebuffer_client::sCheckFramebufferState,
0,
0,
0,
0,
},
{
(IOExternalMethodAction) &info_ennowelbers_syphon_proxyframebuffer_client::sUpdateMemory,
0,
0,
0,
0,
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sGetModeCount,
0,
0,
0,
0,
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sGetModeInfo,
1,
0,
0,
sizeof(EWProxyFramebufferModeInfo),
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sGetCursorState,
0,
0,
3,
0,
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sGetCursorResolution,
0,
0,
2,
0,
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sEnableCursorEvents,
2,
0,
0,
0,
},
{
(IOExternalMethodAction)&info_ennowelbers_syphon_proxyframebuffer_client::sDisableCursorEvents,
0,
0,
0,
0,
}
};

#pragma mark dispatcher function
//as we're having function adresses in our dispatch table, all we need is a range check and check the target.
IOReturn info_ennowelbers_syphon_proxyframebuffer_client::externalMethod(uint32_t selector, IOExternalMethodArguments* arguments, IOExternalMethodDispatch* dispatch, OSObject *target, void *reference)
{
	if(selector < (uint32_t) kNumberOfMethods) {
		dispatch=(IOExternalMethodDispatch*)&sMethods[selector];
		if(!target)
		{
			target=this;
		}
	}
	return super::externalMethod(selector, arguments, dispatch, target, reference);
}

#pragma mark IOUserClient functions
//for these functions, see apple docs.
bool info_ennowelbers_syphon_proxyframebuffer_client::initWithTask(task_t owningTask, void* securityToken, UInt32 type, OSDictionary *properties)
{
	bool success;
	
	success=super::initWithTask(owningTask, securityToken, type, properties);
	
	fTask=owningTask;
	fProvider=NULL;
	owningFB=NULL;
	return success;
}

bool info_ennowelbers_syphon_proxyframebuffer_client::start(IOService *provider)
{
	bool success;
	
	fProvider= OSDynamicCast(info_ennowelbers_syphon_proxyframebuffer_driver, provider);
	success=(fProvider!=NULL);
	if(success) {
		success=super::start(provider);
	}
	return success;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::clientClose()
{
	if(owningFB)
	{
		StopFramebuffer();
	}
	if(eventEnabled)
	{
		fProvider->eventClient=NULL;
	}
	terminate();
	return kIOReturnSuccess;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::clientDied()
{
	if(owningFB)
	{
		StopFramebuffer();
	}
	if(eventEnabled)
	{
		fProvider->eventClient=NULL;
	}
	return super::clientDied();
}

//This one is used to send events to user space.
IOReturn info_ennowelbers_syphon_proxyframebuffer_client::registerNotificationPort(mach_port_t port, UInt32 type, UInt32 refCon )
{
	eventPort=port;
	return kIOReturnSuccess;
}

#pragma mark static functions
//these functions are part of the "calling chain"
//actually they do ... nothing special. Converting parameters, calling member functions.

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sStartFramebuffer(info_ennowelbers_syphon_proxyframebuffer_client *target, void * reference, IOExternalMethodArguments *arguments)
{
	IOReturn ret=target->StartFramebuffer(arguments->scalarInput[0]);
	return ret;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sStopFramebuffer(info_ennowelbers_syphon_proxyframebuffer_client *target, void * reference, IOExternalMethodArguments *arguments)
{
	IOReturn ret=target->StopFramebuffer();
	return ret;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sCheckFramebufferState(info_ennowelbers_syphon_proxyframebuffer_client *target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->CheckFramebufferState();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sUpdateMemory(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->UpdateMemory();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sGetModeCount(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->GetModeCount();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sGetModeInfo(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	IOLog("EWProxyFrameBuffer: Client static Get Mode Info!\n");
	IOReturn ret= target->GetModeInfo(arguments->scalarInput[0], (EWProxyFramebufferModeInfo*)arguments->structureOutput);
	arguments->structureOutputSize=sizeof(EWProxyFramebufferModeInfo);
	return ret;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sGetCursorState(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->GetCursorState((int*)&arguments->scalarOutput[0], (int*)&arguments->scalarOutput[1], (bool*)&arguments->scalarOutput[2]);
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sGetCursorResolution(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->GetCursorResolution((int*)&arguments->scalarOutput[0], (int*)&arguments->scalarOutput[1]);
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sEnableCursorEvents(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
#ifdef __LP64__
	return target->EnableCursorEvents((mach_vm_address_t)(arguments->scalarInput[0]), (io_user_reference_t)(arguments->scalarInput[1]));
#else
	return target->EnableCursorEvents((void*)(arguments->scalarInput[0]), (void*)(arguments->scalarInput[1]));
#endif
}

#pragma mark member functions of the call chaing
//these functions access the driver variables and provides results

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::GetCursorState(int *x, int *y, bool *visible)
{
	*x=fProvider->fbuffer->cursorX;
	*y=fProvider->fbuffer->cursorY;
	*visible=fProvider->fbuffer->cursorVisible;
	return kIOReturnSuccess;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::GetCursorResolution(int *width, int *height)
{
	*width=fProvider->fbuffer->cursorWidth;
	*height=fProvider->fbuffer->cursorHeight;
	return kIOReturnSuccess;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::StartFramebuffer(int mode)
{
	IOReturn ret= fProvider->StartFramebuffer(mode);
	if(ret==kIOReturnSuccess)
	{
		owningFB=true;
	}
	return ret;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::StopFramebuffer()
{
	IOReturn ret= fProvider->StopFramebuffer();
	if(ret==kIOReturnSuccess)
	{
		owningFB=false;
	}

	return ret;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::CheckFramebufferState()
{
	return fProvider->CheckFramebufferState();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::UpdateMemory()
{
	return fProvider->UpdateMemory();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::GetModeCount()
{
	return fProvider->getModeCount();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::GetModeInfo(int mode,EWProxyFramebufferModeInfo *info)
{
	IOLog("EWProxyFrameBuffer: client->GetModeInfo(%d)\n",mode);
	return fProvider->getmodeInfo(mode, info);
}
IOReturn info_ennowelbers_syphon_proxyframebuffer_client::clientMemoryForType( UInt32 type, IOOptionBits * options, IOMemoryDescriptor ** memory )
{
	IOMemoryDescriptor *mem;
	switch(type)
	{
		case 0:
			mem=(IOMemoryDescriptor*)fProvider->buffer;
			break;
		case 1:
			mem=(IOMemoryDescriptor*)fProvider->fbuffer->cursorMem;
			break;
	}
	mem->retain();
	if(mem==NULL)
		return kIOReturnError;
	*memory=mem;
	return kIOReturnSuccess;
}

void info_ennowelbers_syphon_proxyframebuffer_client::FireCursorStateChanged()
{
	if(eventEnabled)
	{
		//With the help of a previously registered event we're firing it.
#ifdef __LP64__
		io_user_reference_t type[1]={(io_user_reference_t)kEWProxyCursorStateChanged};
        sendAsyncResult64(eventFunction, kIOReturnSuccess,type,1);
#else
		void *type[1]={(void*)kEWProxyCursorStateChanged};
		sendAsyncResult(eventFunction, kIOReturnSuccess, type, 1);
#endif
	}
}

void info_ennowelbers_syphon_proxyframebuffer_client::FireCursorImageChanged()
{
	if(eventEnabled)
	{
#ifdef __LP64__
		io_user_reference_t type[1]={(io_user_reference_t)kEWProxyCursorImageChanged};
		sendAsyncResult64(eventFunction,kIOReturnSuccess, type,1);
#else
		void *type[1]={(void*)kEWProxyCursorImageChanged};
		sendAsyncResult(eventFunction,kIOReturnSuccess, type,1);
#endif
	}
}

//registers an event. This is quite fancy from my point of view.
//user client provides a call pointer, a reference and registers an event port (see above)
//these three together form an OSAsyncReference. the SetAsyncReference fills this opaque structure.
//Later on this opaque structure can be used to fire the event.
//I did not yet get the way this works, however in theory you could even transport parameters.
//we're not using them, though.
#ifdef __LP64__
IOReturn info_ennowelbers_syphon_proxyframebuffer_client::EnableCursorEvents(mach_vm_address_t call, io_user_reference_t reference)
#else
IOReturn info_ennowelbers_syphon_proxyframebuffer_client::EnableCursorEvents(void *call, void *reference)
#endif
{
	if(fProvider->eventClient!=NULL)
		return kIOReturnBusy;
#ifdef __LP64__
    setAsyncReference64(eventFunction,eventPort,call,reference);
#else
	setAsyncReference(eventFunction, eventPort, call, reference);
#endif
	eventEnabled=true;
	fProvider->eventClient=this;
	return kIOReturnSuccess;
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::sDisableCursorEvents(info_ennowelbers_syphon_proxyframebuffer_client* target, void *reference, IOExternalMethodArguments *arguments)
{
	return target->DisableCursorEvents();
}

IOReturn info_ennowelbers_syphon_proxyframebuffer_client::DisableCursorEvents()
{
	if(eventEnabled==false)
		return kIOReturnNotAttached;
	eventEnabled=false;
	fProvider->eventClient=NULL;
	return kIOReturnSuccess;
}


