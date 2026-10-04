ARCHS = arm64
TARGET = iphone:clang:latest:12.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VoiceRebuildInjectTest
VoiceRebuildInjectTest_FILES = InjectTest.m
VoiceRebuildInjectTest_CFLAGS = -fobjc-arc
VoiceRebuildInjectTest_FRAMEWORKS = Foundation UIKit
include $(THEOS_MAKE_PATH)/tweak.mk
