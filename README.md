# Syphon Virtual Screen
Not a developer? Check the [project's home page](http://andreacremaschi.github.io/Syphon-virtual-screen/)

Add a fake extra-display to your mac and pipe its video content to use in your video workflow. This can be used i.e. to hijack video output of applications that can go full-screen but are not (yet?) Syphon-enabled.

Based on bangnoise/vade's [Syphon](http://syphon.v002.info) framework and Enno Welber's [EWProxyFrameBuffer](https://github.com/mkernel/EWProxyFramebuffer).

> NB: as tracked in https://github.com/andreacremaschi/Syphon-virtual-screen/issues/33 SVS suffers low framerate with OSX > 10.10. So, currently Yosemite is not supported. Sorry!

## Installing

### Binary

As an alternative to compiling from source, you can just download the latest version from the [releases](https://github.com/andreacremaschi/Syphon-virtual-screen/releases/latest/) section of the project. The package installer will install both the kext and the client app. After rebooting you can find Syphon Virtual Screen in /Applications. Automatic launch at login is disabled by default, but you can find an option to enable it in the application's preference panel.

### Homebrew Cask
     
      brew cask install syphon-virtual-screen
     

### From source

Download the master branch, then update the submodule:

      git submodule update --init

The project will compile in two products: 

- ```EWProxyFramebuffer.kext``` this is the virtual frame buffer driver, and must be correctly installed to work. To install it: copy to /System/Library/Extensions, fix permissions (`sudo chmod -R 755 /System/Library/Extensions/EWProxyFramebuffer.kext`) and ownership (`sudo chown -R root:wheel /System/Library/Extensions/EWProxyFramebuffer.kext`), then clear cache (in Lion, `rm -R /System/Library/Caches/com.apple.kext.caches/Startup`). Now reboot!

- ```Syphon Virtual Screen.app``` this is the client application. Just copy it in /Applications and launch (after installing the kext and reboot)



## Advanced tips

### Using custom resolutions

To use different resolutions you can just modify the ```EWProxyFramebuffer.kext/Contents/Info.plist```.
You can do it both before compiling the kext or downloading the binary and editing the kext configuration. Here is how:


- open the Terminal
- type `sudo su`, enter, type your password
- type `cd /System/Library/Extensions/EWProxyFramebuffer.kext/Contents/`
- type `nano Info.plist`
- find this section:

``` xml
<key>MaxResolution</key>
<dict>
       <key>height</key>
       <integer>1024</integer>
       <key>width</key>
       <integer>1280</integer>
</dict>
```

- and replace ```height``` and ```width``` as you need to:

``` xml
<key>MaxResolution</key>
<dict>
       <key>height</key>
       <integer>1050</integer>
       <key>width</key>
       <integer>1680</integer>
</dict>
```

- a little above this section you’ll find a list of available resolutions within `dict`, the last one being the highest resolution:

``` xml
<dict>
     <key>height</key>
     <integer>1024</integer>
     <key>name</key>
     <string>1280x1024</string>
     <key>width</key>
     <integer>1280</integer>
</dict>
```

- add the resolution you need as a new `dict` entry:

``` xml
<dict>
     <key>height</key>
     <integer>1050</integer>
     <key>name</key>
     <string>1680x1050</string>
     <key>width</key>
     <integer>1680</integer>
</dict>
```

- type “Ctrl+X” to save your editing

- now, back in terminal, you have to repair permissions for the driver you’ve just modified. Type:

```
sudo chmod -R 755 /System/Library/Extensions/EWProxyFramebuffer.kext
sudo chown -R root:wheel /System/Library/Extensions/EWProxyFramebuffer.kext
```

- delete the kext cache with the following command:

```sudo rm -R /System/Library/Caches/com.apple.kext.caches/Startup```

- reboot
