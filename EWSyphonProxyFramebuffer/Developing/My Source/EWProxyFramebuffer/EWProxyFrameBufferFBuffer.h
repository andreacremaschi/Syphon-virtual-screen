/*
 *  PSPScreenFBuf.h
 *  PSPScreenDriver
 *
 *  Created by Enno Welbers on 28.02.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */
#ifndef EWPROXYFRAMEBUFFERFBUFFER_H__
#define EWPROXYFRAMEBUFFERFBUFFER_H__

#include <IOKit/IOService.h>
#include <IOKit/graphics/IOFramebuffer.h>

class info_ennowelbers_proxyframebuffer_driver;

//this class is the real framebuffer implementation.
//it handles a lot of stuff OS X wants from it.
//and it does some strange things on first sight. I promise these were nessecary
//in order to get it "up and running"
class info_ennowelbers_proxyframebuffer_fbuffer : public IOFramebuffer
{
OSDeclareDefaultStructors(info_ennowelbers_proxyframebuffer_fbuffer)
private:
	info_ennowelbers_proxyframebuffer_driver *fProvider;
	IOBufferMemoryDescriptor *graphicMem;
	IOMemoryMap *cursorMapping;
	UInt8 *cursorBuf;
	unsigned int graphicSize;
	bool started;
	bool connected;
	unsigned int mode;
	bool warmup;
public:
	IOBufferMemoryDescriptor *cursorMem;
	int cursorWidth;
	int cursorHeight;
	int cursorX;
	int cursorY;
	bool cursorVisible;
	virtual bool init(OSDictionary *dictionary=0);
	virtual void free(void);
	virtual bool start(IOService *provider);
	virtual void stop(IOService *provider);
		
	virtual IOReturn enableController();
	virtual IODeviceMemory * getApertureRange( IOPixelAperture aperture );
	virtual IOReturn getCurrentDisplayMode(IODisplayModeID * displayMode,IOIndex * depth);
	virtual IOItemCount getDisplayModeCount();
	virtual IOReturn getDisplayModes(IODisplayModeID * allDisplayModes);
	virtual IOReturn getInformationForDisplayMode(IODisplayModeID displayMode, IODisplayModeInformation * info);
	virtual const char * getPixelFormats();
	virtual UInt64 getPixelFormatsForDisplayMode(IODisplayModeID displayMode, IOIndex depth);
	virtual IOReturn getPixelInformation(IODisplayModeID displayMode, IOIndex depth, IOPixelAperture aperture, IOPixelInformation * pixelInfo);
	virtual IOReturn getStartupDisplayMode(IODisplayModeID * displayMode, IOIndex * depth);
	virtual IODeviceMemory * getVRAMRange();
	virtual IOReturn setDisplayMode(IODisplayModeID displayMode, IOIndex depth);
    virtual IOItemCount getConnectionCount( void );
	virtual IOReturn getAttributeForConnection(IOIndex connectIndex, IOSelect attribute, uintptr_t *value);
	virtual IOReturn setAttributeForConnection(IOIndex connection, IOSelect attribute, uintptr_t value);
	IOReturn setAttribute( IOSelect attribute, uintptr_t value );
	IOReturn getAttribute( IOSelect attribute, uintptr_t * value );

	virtual IOReturn Connect(int mode);
	virtual IOReturn Disconnect();
	virtual IOReturn State();
	virtual void SwitchResolution();
	
	virtual IOReturn setCursorImage(void *img);
	virtual IOReturn setCursorState(SInt32 x, SInt32 y, bool visible);
};

#endif