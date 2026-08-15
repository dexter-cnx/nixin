# Canonical project identity for Dextryx Images.
# These values are intentionally committed: bundle/application IDs and Apple
# Team IDs are project metadata, not secrets.

APP_ID ?= com.cnxdev.dextryx.images
APPLE_TEAM_ID ?= ZTM9BCJPY9
PRODUCT_NAME ?= Dextryx Images
APP_NAME ?= Dxtr Imgs

# Platform-specific defaults can be overridden from the command line/CI.
ANDROID_APPLICATION_ID ?= $(APP_ID)
ANDROID_NAMESPACE ?= $(APP_ID)
IOS_BUNDLE_ID ?= $(APP_ID)
MACOS_BUNDLE_ID ?= $(APP_ID)
TEST_BUNDLE_SUFFIX ?= RunnerTests
