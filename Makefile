INSTALL_TARGET_PROCESSES = AlightMotion

ARCHS = arm64
TARGET = iphone:clang:14.5:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = AlightMotionAutoExport
ifeq ($(BUILD_B),1)
AlightMotionAutoExport_FILES = Tweak_BuildB_Minimal.m
else
AlightMotionAutoExport_FILES = Tweak_Full_Protected.m fishhook.c
endif

AlightMotionAutoExport_CFLAGS = -fobjc-arc -Wno-error -Wno-unused-variable -Wno-unused-function
AlightMotionAutoExport_FRAMEWORKS = UIKit UserNotifications Photos QuartzCore AudioToolbox AVFoundation CoreMedia CoreImage VideoToolbox Metal MetalKit Security

include $(THEOS_MAKE_PATH)/library.mk
