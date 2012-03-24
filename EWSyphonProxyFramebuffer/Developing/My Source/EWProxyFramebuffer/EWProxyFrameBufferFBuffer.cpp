/*
 *  PSPScreenFBuf.cpp
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include <IOKit/IOLib.h>
#include <IOKit/IOBufferMemoryDescriptor.h>
#include <IOKit/graphics/IOGraphicsInterfaceTypes.h>
#include "EWProxyFrameBufferClient.h"
#include "EWProxyFrameBuffer.h"
#include "EWProxyFrameBufferDriver.h"

//I didn't have time (yet) to implement an interrupt management
//therefore i rely upon the already available implementation from apple.
//but... you can't fire these interrupts without this macro and the presence
//of a private header (part of the project).
#define IOFRAMEBUFFER_PRIVATE
#include "EWProxyFrameBufferFBuffer.h"
#undef IOFRAMEBUFFER_PRIVATE

extern "C" {
#include <pexpert/pexpert.h>//this is for debugging only
}

#define kIOPMIsPowerManagedKey          "IOPMIsPowerManaged"

#define super IOFramebuffer

OSDefineMetaClassAndStructors(info_ennowelbers_proxyframebuffer_fbuffer, IOFramebuffer)

#pragma mark Functions used by user space
//all these functions are called indirectly due to a running user space application

IOReturn info_ennowelbers_proxyframebuffer_fbuffer::Connect(int mode)
{
	if(connected)
		return kIOReturnStillOpen;
	else
	{
		EWProxyFramebufferModeInfo info;
		//first we need to get the mode in order to tell OS about it.
		int ret=fProvider->getmodeInfo(mode, &info);
		if(ret!=kIOReturnSuccess)
			return kIOReturnBadArgument;
		this->mode=mode;
		IOLog("EWProxyFrameBuffer: mode is now %d\n",mode);
		//helper variables for disconnect and in order to prepare mode switch without
		//disconnecting (i think).
		connected=true;
		warmup=true;
		//this call is the reason for the private header
		connectChangeInterrupt(this,0);
		return kIOReturnSuccess;
	}
}

IOReturn info_ennowelbers_proxyframebuffer_fbuffer::Disconnect()
{
	if(connected)
	{
		connected=false;
		//tell OS that we have no screen.
		connectChangeInterrupt(this,0);
		return kIOReturnSuccess;
	}
	else
	{
		return kIOReturnNotOpen;
	}
}

IOReturn info_ennowelbers_proxyframebuffer_fbuffer::State()
{
	if(!connected)
		return 0;
	else
		return mode;
}

//this function is left behind.
//i wanted the framebuffer to be able to switch resolution from our client 
//(not from OS side), but it was not possible. OS ignores resolutions switches
//other than those originating from OS. It is Borg.
void info_ennowelbers_proxyframebuffer_fbuffer::SwitchResolution()
{
	if(warmup)
	{
		handleEvent(kIOFBNotifyDisplayModeWillChange, NULL);
		handleEvent(kIOFBNotifyDisplayModeDidChange, NULL);
		warmup=false;
	}
}

#pragma mark Framebuffer functions
//This Function is used by OS to fetch driver capabilities.
//The only thing we support is a hardware cursor
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getAttribute( IOSelect attribute, uintptr_t * value )
{
	union myvar
	{
		IOSelect attribute;
		char param[5];
	};
	myvar var;
	var.attribute=attribute;
	var.param[4]='\0';
	IOLog("EWProxyFrameBuffer: getAttribute(%s).\n",var.param);
	IOReturn ret= super::getAttribute(attribute, value);
	if(attribute==kIOHardwareCursorAttribute)
	{
		*value=0;
		ret= kIOReturnSuccess;
	}
	if(value!=NULL)
		IOLog("EWProxyFrameBuffer: Value= %x, Ret=%x\n",(unsigned int)*value,ret);
	else
		IOLog("EWProxyFrameBuffer: Ret=%x\n",ret);
	return ret;
	
}

//This Function is used by OS to command the driver.
//the important ones:
//CAPTURE: during bootup at a certain point AQUIRE is set.
//         that means that now the OS really starts using the framebuffer
//         before the aquire command OS is fetching information.
//         and before aquire the framebuffer has to tell that the screen is connected
//         otherwise it is ignored (there was no screen during information gathering, so there will never be one...)
//Power:   power our virtual hardware on or off
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::setAttribute( IOSelect attribute, uintptr_t value )
{
	IOReturn ret=super::setAttribute(attribute, value);
	union myvar
	{
		IOSelect attribute;
		char param[5];
	};
	myvar var;
	var.attribute=attribute;
	var.param[4]='\0';
	if(attribute==kIOCapturedAttribute)
	{
		if(started==false)
		{
			started=true;
			connectChangeInterrupt(this,0);
		}
	}
	if(attribute==kIOPowerAttribute)
	{
		handleEvent((value>=1 ? kIOFBNotifyWillPowerOn : kIOFBNotifyWillPowerOff), NULL);
		handleEvent((value>=1 ? kIOFBNotifyDidPowerOn : kIOFBNotifyDidPowerOff), NULL);
		ret=kIOReturnSuccess;
	}
	IOLog("EWProxyFrameBuffer: setAttribute(%s,%x)=%x\n",var.param,(unsigned int)value,ret);
	return ret;
}

//Every framebuffer has (in theory) at least (but not limited to) one connection.
//that is... the thing where you plug in your screen.
//however, documentation tells that "good habit" is to have one framebuffer per screen.
//The *AttributeForConnection functions are used to gather information about / drive a connected screen
//We're not powering any hardware, but we still need to tell "done" upon power changes
//Concerning Probe:
//As far as i recall, whenever a framebuffer tells OS about a screen change, it calls Probe on
//all connections on all framebuffers. When the connection really changed, the framebuffer should tell
//by re-interrupting again. Actually this implementation is not correct, however
//OS understands it. It simply means that whenever a real screen is (dis)connected, our virtual one is
//reconnected. OS can handle it... 
//TODO
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::setAttributeForConnection(IOIndex connection, IOSelect attribute, uintptr_t value)
{
	if(attribute==kConnectionProbe)
	{
		IOLog("EWProxyFrameBuffer: Sense!\n");
		connectChangeInterrupt(this,0);
//		if(interrupts[1]!=NULL)
//		{
//			interrupts[1](interruptTargets[1],interruptRefs[1]);
//		}
		return kIOReturnSuccess;
	}
	if(attribute==kConnectionPower)
	{
		return kIOReturnSuccess;
	}
	IOReturn ret=super::setAttributeForConnection(connection,attribute, value);
	union myvar
	{
		IOSelect attribute;
		char param[5];
	};
	myvar var;
	var.attribute=attribute;
	var.param[4]='\0';
	IOLog("EWProxyFrameBuffer: setAttributeForConnection(%d,%s,%x)=%x\n",(int)connection,var.param,(unsigned int)value,(unsigned int)ret);
	return ret;
	
}

//There is only one interesting Attribute OS reads for each connection
//The "is there a screen connected?" attribute.
//If we're not aquired, we have to return 1.
//If we're aquired, we have to tell the truth.
//
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getAttributeForConnection(IOIndex connectIndex, IOSelect attribute, uintptr_t *value)
{
	union myvar
	{
		IOSelect attribute;
		char param[5];
	};
	myvar var;
	var.attribute=attribute;
	var.param[4]='\0';
	IOLog("EWProxyFrameBuffer: getAttributeForConnection(%d,%s).\n",(int)connectIndex,var.param);
	if(attribute==kConnectionEnable || attribute==kConnectionCheckEnable)
	{
		if(value!=NULL)
		{
			if(connected==false)
				*value=0;
			else
				*value=1;
			//if(started==false)
			//	*value=1;
		}
		return kIOReturnSuccess;
	}
//	if(attribute==kConnectionFlags)
//	{
//		if(value!=NULL)
//			*value=0;
//		return kIOReturnSuccess;
//	}
//	if(attribute==kConnectionChanged)
//	{
//		if(value!=NULL)
//			*value=0;
//		return kIOReturnSuccess;
//	}
	IOReturn ret= super::getAttributeForConnection(connectIndex, attribute, value);
	if(value!=NULL)
		IOLog("EWProxyFrameBuffer: Value= %x, Ret=%x\n",(unsigned int)*value,ret);
	else
		IOLog("EWProxyFrameBuffer: Ret=%x\n",ret);
	return ret;
}

bool info_ennowelbers_proxyframebuffer_fbuffer::init(OSDictionary *dict)
{
	bool res = super::init(dict);
	IOLog("EWProxyFrameBuffer: FBINIT\n");
	return res;
}

//OS is greedy. Once a framebuffer is in the Registry, it will not go away.
//so this function only exists to stop the compiler from warning. 
void info_ennowelbers_proxyframebuffer_fbuffer::free(void)
{
	IOLog("EWProxyFrameBuffer: Free\n");
	super::free();
}

bool info_ennowelbers_proxyframebuffer_fbuffer::start(IOService *provider)
{
	bool res=super::start(provider);
	//PMinit();
	connected=0;
	graphicMem=NULL;
	started=false;
	fProvider=OSDynamicCast(info_ennowelbers_proxyframebuffer_driver,provider);
	if(res && fProvider!=NULL)
	{
		//fProvider->joinPMtree(this);
	}
	IOLog("EWProxyFrameBuffer: Starting\n");
	if(fProvider==NULL)
		return false;
	return res;
}

void info_ennowelbers_proxyframebuffer_fbuffer::stop(IOService *provider)
{
	super::stop(provider);
	if(graphicMem!=NULL)
	{
		cursorMapping->release();
		cursorMem->release();
		cursorMem=NULL;
		graphicMem->release();
		graphicMem=NULL;
	}
	IOLog("EWProxyFrameBuffer: Stopping\n");
}

//provides OS with the memory range dependend on our current resolution
IODeviceMemory * info_ennowelbers_proxyframebuffer_fbuffer::getApertureRange(IOPixelAperture aperture)
{
	IOLog("EWProxyFrameBuffer: getApertureRange\n");
	EWProxyFramebufferModeInfo info;
	fProvider->getmodeInfo(mode, &info);
	IODeviceMemory *dev=IODeviceMemory::withSubRange((IODeviceMemory*)graphicMem,0,(info.height*(info.width*4+32)+128));
//	IODeviceMemory *dev=IODeviceMemory::withRange(graphicPhysVRAM, (fProvider->height*(fProvider->width*4+32)+128));
	return dev;
}

//OS is greedy when it comes to graphic memory. It wants the whole thing.
//and... it releases it, so we're overretaining here
IODeviceMemory * info_ennowelbers_proxyframebuffer_fbuffer::getVRAMRange()
{
	IOLog("EWProxyFrameBuffer: getVRAMRange\n");
	graphicMem->retain();
	return (IODeviceMemory*)graphicMem;
}


//this one gets called when OS is ready for our hardware.
//we should to all the hardware initialization stuff in here
//as we're forced to have the graphic mem around all the time
//we're initializing by allocating worst-case-buffers
//and keep them.
//Framebuffer magic: Framebuffers only work when present during boot
//                   Framebuffers only work when having a screen before aquire()
//                   Framebuffers only work when having graphic mem
//Remember: this memory is aquired during boot and will be completely gone
//          Therefore it's preferred to set a constrained max resolution
//          and forbidden to go to higher resolutions than that.
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::enableController()
{
	IOLog("EWProxyFrameBuffer: enableController\n");
	//I have no idea why we need 32 extra bytes per row and 128 bytes extra, but...
	//it only works with these extra buffers
	//Size adaption: to increase memory, I provide 1k per line and 1 meg at the end
	//this is for ansgar!
	//graphicSize=fProvider->getMaxHeight()*(fProvider->getMaxWidth()*4+32)+128;//width*height*4 buffer size, enough space for 4 buffers
	graphicSize=fProvider->getMaxHeight()*(fProvider->getMaxWidth()*4+1024)+10490880;//width*height*4 buffer size, enough space for 4 buffers
	while( graphicSize % PAGE_SIZE != 0)
	{
		graphicSize++;
	}
	mode=1;
//	graphicSize=graphicSize*4;
//	graphicMem=IODeviceMemory::withRange(graphicPhysVRAM, graphicSize);
//	apertureMem=IODeviceMemory::withRange(graphicPhysVRAM,graphicSize/4);
//	graphicMem=IOBufferMemoryDescriptor::withOptions(kIODirectionInOut|kIOMemoryKernelUserShared,graphicSize,PAGE_SIZE);
	graphicMem=IOBufferMemoryDescriptor::withCapacity(graphicSize, kIODirectionInOut);
	//i'm not sure whether we could reduce this size, at least that's a very huge cursor.
	cursorMem=IOBufferMemoryDescriptor::withCapacity((320*4+32)*320+128, kIODirectionInOut);//cursor buffer, 320x320 px cursor size maximum;
	cursorMapping=cursorMem->map(kIOMapAnywhere);
	cursorBuf=(UInt8*)cursorMapping->getVirtualAddress();
	IOLog("EWProxyFrameBuffer: controller memory: size=%d bytes\n",graphicSize);
	if(graphicMem==NULL)
	{
		IOLog("EWProxyFrameBuffer: unable to reserve memory!\n");
	}
//	IOLog("IODeviceMemory: %x\n",(int)apertureMem);
	//power management is explained (a bit) in EWProxyFrameBufferDriver
	static IOPMPowerState myPowerStates[3];
//    getProvider()->joinPMtree(this);
	myPowerStates[0].version=1;
	myPowerStates[0].capabilityFlags=0;
	myPowerStates[0].outputPowerCharacter=0;
	myPowerStates[0].inputPowerRequirement=0;
	myPowerStates[1].version=1;
	myPowerStates[1].capabilityFlags=0;
	myPowerStates[1].outputPowerCharacter=0;
	myPowerStates[1].inputPowerRequirement=IOPMPowerOn;
	myPowerStates[2].version=1;
	myPowerStates[2].capabilityFlags=IOPMDeviceUsable;
	myPowerStates[2].outputPowerCharacter=IOPMPowerOn;
	myPowerStates[2].inputPowerRequirement=IOPMPowerOn;
	registerPowerDriver(this, myPowerStates, 3);
	temporaryPowerClampOn();
	changePowerStateTo(2);
	getProvider()->setProperty(kIOPMIsPowerManagedKey, true);
	return kIOReturnSuccess;
}

//as told above, framebuffers could have more than one screen (in theory).
//but... OS doesn't support it. i think. They tell us to return 1.
IOItemCount info_ennowelbers_proxyframebuffer_fbuffer::getConnectionCount()
{
	/*if(connected==0)result=0;
	else
		result=1;*/
	IOLog("EWProxyFrameBuffer: GetConnectionCount()=1\n");
	return 1;
}

//This Function is used by OS to get current Display Mode
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getCurrentDisplayMode(IODisplayModeID * displayMode, IOIndex * depth)
{
	IOLog("EWProxyFrameBuffer: getCurrentDisplayMode\n");
	if(displayMode==NULL)
		return kIOReturnBadArgument;
	if(depth==NULL)
		return kIOReturnBadArgument;
	*displayMode=mode;
	*depth=0;
	return kIOReturnSuccess;
}

//OS wants to fill lists and needs the total amount of possible modes
IOItemCount info_ennowelbers_proxyframebuffer_fbuffer::getDisplayModeCount()
{
	IOLog("EWProxyFrameBuffer: getDisplayModeCount\n");
	return fProvider->getModeCount();
}

//OS first calls getDisplayModeCount, allocates a buffer and then calls getModes.
//so the pointer is garantueed to be big enough for the number of modes given before.
//the funny thing: a display mode is ... an integer. 
//all the other information are transported using getInformationForDisplayMode
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getDisplayModes(IODisplayModeID * allDisplayModes)
{
	IOLog("EWProxyFrameBuffer: getDisplayModes\n");
	for(int i=1;i<=fProvider->getModeCount();i++)
	{
		allDisplayModes[i-1]=i;
	}
	return kIOReturnSuccess;
}

//returns details about a given display mode (width, height, refresh rate, flags, amount of possible depths)
//i have no knowledge about those flags. that way they work.
//an extension would be (to prevent OS from switching) to make them visible based on the current mode setting
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getInformationForDisplayMode(IODisplayModeID displayMode, IODisplayModeInformation *info)
{
	IOLog("EWProxyFrameBuffer: getInformationForDisplayMode\n");
	EWProxyFramebufferModeInfo pinfo;
	IOReturn ret=fProvider->getmodeInfo(displayMode, &pinfo);
	if(ret!=kIOReturnSuccess)
		return ret;
	bzero(info,sizeof(*info));
	info->nominalWidth=pinfo.width;
	info->nominalHeight=pinfo.height;
	info->maxDepthIndex=0;
	info->refreshRate=60<<16;
	info->flags=kDisplayModeAlwaysShowFlag|kDisplayModeValidFlag|kDisplayModeDefaultFlag;
	return kIOReturnSuccess;
}

//In theory the graphic mem could be in different formats.
//I have no idea about their physical layout in memory. 
//The details about this pixel format are ... in our domain.
//After asking us for a name OS asks for details with getPixelInformation.
const char * info_ennowelbers_proxyframebuffer_fbuffer::getPixelFormats()
{
	IOLog("EWProxyFrameBuffer: getPixelFormats\n");
	static const char * fmts=IO32BitDirectPixels "\0\0";
	return fmts;
}

//this function is deprecated from what i recall
UInt64 info_ennowelbers_proxyframebuffer_fbuffer::getPixelFormatsForDisplayMode(IODisplayModeID displayMode, IOIndex depth)
{
	IOLog("EWProxyFrameBuffer: getPixelFormatsForDisplayMode\n");
	return 0;
}

//This function tells OS where in these 32 bits are red, green and blue, how many bits each component we use and how
//many components we really use.
//we could save some space by using a smaller pixel layout, but we need to convert it into a CGImage in user space, 
//this is the simplest copy routine.
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getPixelInformation(IODisplayModeID displayMode, IOIndex depth, IOPixelAperture aperture, IOPixelInformation * pixelInfo)
{
	IOLog("EWProxyFrameBuffer: getPixelInformation(mode=%x, depth=%x, aperture=%x)\n",(int)displayMode,(int)depth,(int)aperture);
	if(depth!=0)
	{
		IOLog("EWProxyFrameBuffer: Unsupported!\n");
		return kIOReturnUnsupportedMode;
	}
	else
	{
		EWProxyFramebufferModeInfo pinfo;
		IOReturn ret=fProvider->getmodeInfo(displayMode, &pinfo);
		if(ret!=kIOReturnSuccess)
			return ret;
		bzero(pixelInfo,sizeof(*pixelInfo));
		IOLog("EWProxyFrameBuffer: returning for %d x %d\n",pinfo.width,pinfo.height);
		pixelInfo->bytesPerRow=pinfo.width*4+32;//32 byte row header??
		pixelInfo->bitsPerPixel=32;
		pixelInfo->pixelType=kIORGBDirectPixels;
		pixelInfo->componentCount=3;
		pixelInfo->bitsPerComponent=8;
		strlcpy(pixelInfo->pixelFormat, IO32BitDirectPixels, sizeof(pixelInfo->pixelFormat));
		pixelInfo->activeWidth=pinfo.width;
		pixelInfo->activeHeight=pinfo.height;
		pixelInfo->componentMasks[0]=0x00FF0000;
		pixelInfo->componentMasks[1]=0x0000FF00;
		pixelInfo->componentMasks[2]=0x000000FF;
		IOLog("EWProxyFrameBuffer: Pixel Data: bytesPerRow=%d bytesPerPlane=%d bitsPerPixel=%d pixelType=%d components=%d bitsPerComponent=%d pixelformat=%s width=%d height=%d masks(%x,%x,%x)\n",
			  (int)pixelInfo->bytesPerRow,(int)pixelInfo->bytesPerPlane,(int)pixelInfo->bitsPerPixel,(int)pixelInfo->pixelType,(int)pixelInfo->componentCount, (int)pixelInfo->bitsPerComponent,pixelInfo->pixelFormat,
			  (int)pixelInfo->activeWidth,(int)pixelInfo->activeHeight,(unsigned int)pixelInfo->componentMasks[0],(unsigned int)pixelInfo->componentMasks[1],(unsigned int)pixelInfo->componentMasks[2]);
	}
	return kIOReturnSuccess;
}

//OS uses this function to switch mode
//currently we always return unsupported but we still tell OS that resolution changed
//would be better to only show the mode currently configured.
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::setDisplayMode(IODisplayModeID displayMode, IOIndex depth)
{
	IOLog("EWProxyFrameBuffer: setDisplayMode(%x,%d)\n",(unsigned int)displayMode,(int)depth);
	if(displayMode<1 || displayMode>fProvider->getModeCount() || depth!=0) 
	{
		IOLog("EWProxyFrameBuffer: unsupported mode!\n");
		return kIOReturnUnsupportedMode;
	}
	if(mode!=displayMode)
	{
		return kIOReturnUnsupportedMode;
	}
	mode=displayMode;
	handleEvent(kIOFBNotifyDisplayModeWillChange, NULL);
	handleEvent(kIOFBNotifyDisplayModeDidChange, NULL);
	return kIOReturnSuccess;
}

//OS uses this function to provide us with a new cursor image
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::setCursorImage(void *img)
{
	IOHardwareCursorDescriptor cdesc;
	IOHardwareCursorInfo cinfo;
	
	cdesc.majorVersion=kHardwareCursorDescriptorMajorVersion;
	cdesc.minorVersion=kHardwareCursorDescriptorMinorVersion;
	cdesc.height=320;
	cdesc.width=320;
	cdesc.bitDepth=kIO32ARGBPixelFormat;
	cdesc.maskBitDepth=0;
	cdesc.numColors=0;
	cdesc.colorEncodings=NULL;
	cdesc.flags=0;
	cdesc.supportedSpecialEncodings=0;
	memset(cdesc.specialEncodings, 0, sizeof(cdesc.specialEncodings));
	
	cinfo.majorVersion=kHardwareCursorInfoMajorVersion;
	cinfo.minorVersion=kHardwareCursorInfoMinorVersion;
	cinfo.colorMap=NULL;
	memset(cinfo.reserved, 0, sizeof(cinfo.reserved));
	cinfo.hardwareCursorData=cursorBuf;
	//the cool thing: as we only get a pointer we have no idea about it's format.
	//therefore we define the format we want (see structures above)
	//and tell OS (parent class, essentially) to convert it.
	//img is our own buffer. We don't even need to copy it into our buffer afterwards.
	bool ret=convertCursorImage(img, &cdesc, &cinfo);
	IOLog("EWProxyFrameBuffer: convertCursorImage()=%s\n",(ret?"true":"false"));
	if(ret)
	{
		IOLog("EWProxyFrameBuffer: cursor size: %d x %d\n",(int)cinfo.cursorWidth,(int)cinfo.cursorHeight);
		cursorWidth=cinfo.cursorWidth;
		cursorHeight=cinfo.cursorHeight;
		//our user space app can register a few events
		//one of those is "cursor changed"
		//here we're firing this event.
		if(fProvider->eventClient!=NULL)
		{
			fProvider->eventClient->FireCursorImageChanged();
		}
		return kIOReturnSuccess;
	}
	//for step one we always return unsupported. we just want to get the cursor image
	return kIOReturnUnsupported;
}

//using this function OS tells us where the cursor is and whether it's visible or not.
//don't get me wrong, a framebuffer can work without a hardware cursor.
//OS then draws the cursor directly into graphic mem. Not very effective, though.
IOReturn info_ennowelbers_proxyframebuffer_fbuffer::setCursorState(SInt32 x, SInt32 y, bool visible)
{
	cursorX=x;
	cursorY=y;
	cursorVisible=visible;
	if(fProvider->eventClient!=NULL)
	{
		fProvider->eventClient->FireCursorStateChanged();
	}
	return kIOReturnSuccess;
}

IOReturn info_ennowelbers_proxyframebuffer_fbuffer::getStartupDisplayMode(IODisplayModeID * displayMode, IOIndex * depth)
{
/*    displayMode = 0;
    depth = 00;*/
	return kIOReturnUnsupported;
    
}

