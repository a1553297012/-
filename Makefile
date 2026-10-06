ARCHS = arm64
TARGET = iphone:clang:latest:12.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VoiceBridgeProbe

VoiceBridgeProbe_FILES = InjectTest.m
VoiceBridgeProbe_CFLAGS = -fobjc-arc
VoiceBridgeProbe_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
