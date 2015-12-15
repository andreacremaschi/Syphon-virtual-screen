# Syphon Virtual Screen

**This project has been discontinued, and is no longer being maintained.**

Syphon Virtual Screen was an open source app to add a fake extra-display to your mac and pipe its video content to use in your video workflow. This could be used i.e. to hijack video output of applications that can go full-screen but are not Syphon-enabled.

The project has been discontinued because of some recent changes in OSX 10.10 and greater:

- issues with kext signing (https://github.com/andreacremaschi/Syphon-virtual-screen/issues/27).
- low framerate (https://github.com/andreacremaschi/Syphon-virtual-screen/issues/33) 
- Airplay mirroring broken on 10.9 and greater (https://github.com/andreacremaschi/Syphon-virtual-screen/issues/16)

Source code is still available for reference on the [development branch](https://github.com/andreacremaschi/Syphon-virtual-screen/tree/develop). 

**If you are working on OSX before Yosemite (10.10)** you can find the installer on the [release page](https://github.com/andreacremaschi/Syphon-virtual-screen/releases).

To uninstall SVS you should:

- Remove the "startup at login" item for Syphon Virtual Screen and delete the app from `\Applications`.
- Open the Terminal and type:

```sh
sudo rm -rf /System/Library/Extensions/EWProxyFramebuffer.kext
sudo kextcache -m /System/Library/Caches/com.apple.kext.caches/Startup/Extensions.mkext /System/Library/Extensions
```
- Reboot.