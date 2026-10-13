ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WCAtlas

WCAtlas_FILES = Tweak.xm $(wildcard Sources/*.m) $(wildcard Vendor/Silk/src/*.c)
WCAtlas_CFLAGS = -IVendor/Silk/interface -IVendor/Silk/src -ffunction-sections -fdata-sections
WCAtlas_OBJCFLAGS = -fobjc-arc
WCAtlas_LDFLAGS = -Wl,-dead_strip
WCAtlas_FRAMEWORKS = UIKit Foundation QuartzCore CoreImage Photos AVFoundation AudioToolbox AVKit UniformTypeIdentifiers UserNotifications JavaScriptCore Security

include $(THEOS_MAKE_PATH)/tweak.mk
