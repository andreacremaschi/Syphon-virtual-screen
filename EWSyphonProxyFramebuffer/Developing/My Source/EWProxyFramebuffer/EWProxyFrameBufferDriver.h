#ifndef EWPROXYFRAMEBUFFERDRIVER_H__
#define EWPROXYFRAMEBUFFERDRIVER_H__

#include <IOKit/IOService.h>
#include <IOKit/IOBufferMemoryDescriptor.h>
#include "EWProxyFrameBuffer.h"

class info_ennowelbers_proxyframebuffer_fbuffer;
class info_ennowelbers_proxyframebuffer_client;

/*
 * This class implements the basic driver functionality. It is matched against 
 * IOResource/IOKit and is therefore automatically loaded during bootup/upon installation
 * our plist personality contains a few configuration settings which are used in this class
 * Depending on those settings this class attaches the framebuffer to itself or not.
 * The problem: the framebuffer already has a userclient to communicate with the rest of mac os.
 * so.. if we want to fetch the screen on a different path, we need to have our own user client.
 * but hacking two user clients into one class (the framebuffer) sounded risky. therefore this 
 * two-stage approach. Our framework connects to this class, whereas mac os x connects directly
 * to the framebuffer
 */
class info_ennowelbers_proxyframebuffer_driver: public IOService
{
	OSDeclareDefaultStructors(info_ennowelbers_proxyframebuffer_driver)
private:
	void initFB();
	bool shouldInitFB();
public:
	IOBufferMemoryDescriptor *buffer;
	info_ennowelbers_proxyframebuffer_fbuffer *fbuffer;
	info_ennowelbers_proxyframebuffer_client *eventClient;
	virtual bool init(OSDictionary *dictionary = 0);
	virtual void free(void);
	virtual IOService *probe(IOService *provider, SInt32 *score);
	virtual bool start(IOService *provider);
	virtual void stop(IOService *provider);
	virtual IOReturn setPowerState(unsigned long powerStateOrdinal, IOService *originatingfrom);
	//internal support functions
	virtual unsigned int getMaxWidth();
	virtual unsigned int getMaxHeight();
	
	virtual unsigned int getModeCount();
	virtual IOReturn getAllModes(EWProxyFramebufferModeInfo *mode);
	virtual IOReturn getmodeInfo(unsigned int mode, EWProxyFramebufferModeInfo *result);
	
	//UserClient functions
	IOReturn StartFramebuffer(int mode);
	IOReturn StopFramebuffer();
	IOReturn CheckFramebufferState();
	IOReturn UpdateMemory(void);
};

#endif