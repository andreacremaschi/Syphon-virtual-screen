#include <IOKit/IOLib.h>
#include "EWProxyFrameBufferDriver.h"
//#include "PSPScreenDriver.h"
#include "EWProxyFrameBufferClient.h"
#include "EWProxyFrameBufferFBuffer.h"
#include "EWProxyFrameBuffer.h"

extern "C" {
#include <pexpert/pexpert.h>//This is for debugging only
}

#define super IOService

OSDefineMetaClassAndStructors(info_ennowelbers_syphon_proxyframebuffer_driver, IOService)

bool info_ennowelbers_syphon_proxyframebuffer_driver::init(OSDictionary *dict)
{
	bool res =super::init(dict);
	buffer=NULL;
	//IOLog("Initializing\n");
	return res;
}

//this function is not called when the framebuffer is enabled in plist's settings
//reason: once you have a framebuffer, the system assimilates you (retain count mayhem)
void info_ennowelbers_syphon_proxyframebuffer_driver::free(void)
{
	if(buffer!=NULL)
	{
		buffer->release();
		buffer=NULL;
	}
	//IOLog("Freeing\n");
	super::free();
}

//we're mathing against IOKit/IOResource, so there is no probing, no real one at least.
IOService *info_ennowelbers_syphon_proxyframebuffer_driver::probe(IOService *provider, SInt32 *score)
{
	IOService *res=super::probe(provider,score);
	//IOLog("Probing\n");
	return res;
}

bool info_ennowelbers_syphon_proxyframebuffer_driver::start(IOService *provider)
{
	bool res=super::start(provider);
	if(res)
	{
		//in order to get a framebuffer up and working, we need to correctly configure powermanagement.
		//we're setting up three power states: off, on and usable.
		PMinit();
		getProvider()->joinPMtree(this);
		static IOPMPowerState myPowerStates[3];
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
		//and we're switching to power state USABLE
		changePowerStateTo(2);
		//you need to to this AFTER setting power configuration.
		//at least that's what i recall
		registerService();
		IOLog("EWProxyFrameBuffer: start with maximum resolution %dx%d\n",getMaxWidth(),getMaxHeight());
		if(shouldInitFB())
		{
			IOLog("EWProxyFrameBuffer: Initializing Framebuffer. Unload from this point is impossible.\n");
			initFB();
		}
		else
		{
			IOLog("EWProxyFrameBuffer: Framebuffer initialization deactivated.\n");
		}
		//StartFramebuffer(640, 480);
	}
	//IOLog("Starting\n");
	return res;
}

//reads the plist setting.
bool info_ennowelbers_syphon_proxyframebuffer_driver::shouldInitFB()
{
	OSBoolean *result=(OSBoolean*)getProperty("loadFramebuffer");
	return result->isTrue();
}

//initializes the framebuffer
void info_ennowelbers_syphon_proxyframebuffer_driver::initFB()
{
	if(fbuffer==NULL)
	{
		//IOLog("StartFramebuffer %d %d\n",width,height);
		//lookahead: there is a framebuffer->thisclassuserclient->userspace path to get the screen capture
		//but the framebuffer memory is not a valid image (it contains more than the normal raw image data)
		//therefore we init a buffer to copy the image into. However, we're getting 
		//a memory footprint of twice maxresolution*4, or at least near that scale 
		//(i assume it's even worse, actually... just keep reading my comments)
		unsigned int size=getMaxWidth()*getMaxHeight()*4;
		buffer=IOBufferMemoryDescriptor::withCapacity(size, kIODirectionInOut);
		//IOLog("buffer=%d\n",buffer);
		
		//yes, i'm not using IOKit's matching system here, i simply instanciate on my own.
		//yes, that's NOT the way they want ist, but 
		//now i can control easily whether the framebuffer gets instanciated or not.
		//and all nessecary dictionary keys are documented.
		fbuffer=new info_ennowelbers_syphon_proxyframebuffer_fbuffer();
		
		OSDictionary *dict=OSDictionary::withCapacity(5);
		OSString *bundle=OSString::withCString("info.ennowelbers.syphon.framebuffer");
		OSString *classname=OSString::withCString("info_ennowelbers_syphon_proxyframebuffer_fbuffer");
		OSNumber *debug=OSNumber::withNumber(65535, 32);
		OSString *provider=OSString::withCString("info_ennowelbers_syphon_proxyframebuffer_driver");
		OSString *userclient=OSString::withCString("IOFramebufferUserClient");
		
		dict->setObject("CFBundleIdentifier", bundle);
		dict->setObject("IOClass", classname);
		dict->setObject("IOKitDebug", debug);
		dict->setObject("IOProviderClass", provider);
		dict->setObject("IOUserClientClass", userclient);
		
		bundle->release();
		classname->release();
		debug->release();
		provider->release();
		userclient->release();
		
		fbuffer->init(dict);
		IOLog("EWProxyFrameBuffer: fbuffer retain count: %d\n",fbuffer->getRetainCount());
		dict->release();
		//i forgot why i did this, maybe to ensure that
		//iokit does not mess up with me... 
		//however this is kernel development, trying will keep you rebooting.
		requestProbe(0);
		//attach the framebuffer to this.
		fbuffer->attach(this);
		SInt32 score;
		fbuffer->probe(this, &score);
		fbuffer->start(this);
	}
}

//won't get called with attached framebuffer.
void info_ennowelbers_syphon_proxyframebuffer_driver::stop(IOService *provider)
{
	super::stop(provider);
	PMstop();
	//IOLog("Stopping\n");
}

//we're not having hardware so there is no need to disable it.
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::setPowerState(unsigned long powerStateOrdinal, IOService *originatingfrom)
{
	return super::setPowerState(powerStateOrdinal,originatingfrom);
	//return kIOPMAckImplied;
}

//reads the plist setting MaxResolution->width
//MaxWidth and MaxHeight are used to initialize all buffers.
//See the framebuffer
unsigned int info_ennowelbers_syphon_proxyframebuffer_driver::getMaxWidth()
{
	OSDictionary *dict=(OSDictionary*)getProperty("MaxResolution");
	if(dict==NULL)
		return 640;
	OSNumber *width=(OSNumber*)dict->getObject("width");
	if(width==NULL)
		return 640;
	return width->unsigned32BitValue();
}

//reads the plist setting MaxResolution->height
unsigned int info_ennowelbers_syphon_proxyframebuffer_driver::getMaxHeight()
{
	OSDictionary *dict=(OSDictionary*)getProperty("MaxResolution");
	if(dict==NULL)
		return 480;
	OSNumber *height=(OSNumber*)dict->getObject("height");
	if(height==NULL)
		return 480;
	return height->unsigned32BitValue();
}

//We're not a real graphic card BUT we still need to provide the OS with
//a list of supported modes. Plist configuration is your help
unsigned int info_ennowelbers_syphon_proxyframebuffer_driver::getModeCount()
{
	OSArray *data=(OSArray *)getProperty("DriverModes");
	return data->getCount();
}

//fetches all Screen modes
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::getAllModes(EWProxyFramebufferModeInfo *mode)
{
	OSArray *data=(OSArray *)getProperty("DriverModes");
	EWProxyFramebufferModeInfo *walk=mode;
	for(int i=0;i<data->getCount();i++)
	{
		OSDictionary *dict=(OSDictionary*)data->getObject(i);
		OSString *name=(OSString*)dict->getObject("name");
		OSNumber *width=(OSNumber*)dict->getObject("width");
		OSNumber *height=(OSNumber*)dict->getObject("height");
		strlcpy(mode->name, name->getCStringNoCopy(), sizeof(mode->name));
		walk->width=width->unsigned32BitValue();
		walk->height=height->unsigned32BitValue();
		walk++;
	}
	return kIOReturnSuccess;
}

//fetches a single mode from plist config.
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::getmodeInfo(unsigned int mode, EWProxyFramebufferModeInfo *result)
{
	if(mode<1 || mode>getModeCount())
	{
		return kIOReturnBadArgument;
	}
	OSArray *array=(OSArray*)getProperty("DriverModes");
	OSDictionary *dict=(OSDictionary*)array->getObject(mode-1);
	OSString *name=(OSString*)dict->getObject("name");
	OSNumber *width=(OSNumber*)dict->getObject("width");
	OSNumber *height=(OSNumber*)dict->getObject("height");
	result->width=width->unsigned32BitValue();
	result->height=height->unsigned32BitValue();
	strlcpy(result->name, name->getCStringNoCopy(), sizeof(result->name));
	return kIOReturnSuccess;
}

//we're not hardware based, so a running user space app is acting as hardware
//this call ist just a wrapper targeting the framebuffer to signal a connected display
//To draw a map in your mind: stack trace until OS senses the screen:
//User Space App::Foo()
//IOKit (USER SPACE) exec user client function()
//IOKit (KERNEL SPACE) dispatch
//ewproxyframebufferclient::dispatch(ref,params)
//ewproxyframebufferclient->startframebuffer(mode)
//ewproxyframebufferdriver->startframebuffer(mode)
//ewproxyframebuffer->connect()
//...
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::StartFramebuffer(int mode)
{
	return fbuffer->Connect(mode);
}

//user client wrapper to unplug the screen
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::StopFramebuffer()
{
	return fbuffer->Disconnect();
}

//allows user space to see the state. actually it's bad to call this if the framebuffer is not loaded...
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::CheckFramebufferState()
{
	return fbuffer->State();
}

//this function copies the graphic memory to our buffer so that the user client get's an
//updated image
//i feel that this code will break at some time in the future...
//i did not find any documentation about memory usage and the reasons for 
//the line width and additional headers
IOReturn info_ennowelbers_syphon_proxyframebuffer_driver::UpdateMemory()
{
	if(fbuffer->State()!=0)//fbuffer->connected==1)
	{
        //source memory
		IODeviceMemory *mem=fbuffer->getApertureRange(kIOFBSystemAperture);
		IOMemoryMap *map=mem->map(kIOMapAnywhere);
		unsigned int *buf=(unsigned int*)map->getVirtualAddress();
        
        //target memory
		IOMemoryMap *bmap=buffer->map(kIOMapAnywhere);
		unsigned int *destWalk=(unsigned int*)bmap->getVirtualAddress();
        
		//assumption 1: the system just wants some memory to play with, data start at 0
		//assumption 2: each row has 32 byte ahead
		//assumption 3: each row has 32 byte at the end
		//assumption 4: each row has 32 byte ahead + 128 byte ahead of everything
		//assumption 5: each row has 32 byte at the end + 128 byte ahead of everything
		
		//assumption 3 is correct (32 byte at end of each frame, 128 byte at end of buffer)
		IODisplayModeInformation information;
		fbuffer->getInformationForDisplayMode(fbuffer->State(), &information);
		for(int y=0;y<information.nominalHeight;y++)
		{
			for(int x=0;x<information.nominalWidth;x++)
			{
                *destWalk = *buf; // copy BGRA (assume A is is always set to 0xFF)
                destWalk++;
                buf++;
			}
			buf+=8;
		}
		map->release();
		bmap->release();
		mem->release();
		return kIOReturnSuccess;
	}
	
	return kIOReturnError;
}

