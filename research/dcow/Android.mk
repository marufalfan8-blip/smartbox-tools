LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := dirtycow
LOCAL_SRC_FILES := dirtycow.c
LOCAL_CFLAGS := -O2
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := run-as
LOCAL_SRC_FILES := run-as.c
LOCAL_CFLAGS := -O2
include $(BUILD_EXECUTABLE)
