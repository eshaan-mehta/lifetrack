APP       := LifeTrack
BUNDLE_ID := com.eshaan.lifetrack
IOS_MIN   := 26.0
SIM       := iPhone 18 Pro

# Set by scripts/release.sh. Left empty for dev builds, which keep the
# version already in Resources/Info.plist.
VERSION ?=
BUILD   ?=

# The iOS SDKs only ship inside Xcode.app. xcode-select on this Mac still points at the
# Command Line Tools, so pin Xcode here. Running
#   sudo xcode-select -s /Applications/Xcode.app
# once makes this line unnecessary.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

DEVICE_TRIPLE := arm64-apple-ios$(IOS_MIN)
SIM_TRIPLE    := arm64-apple-ios$(IOS_MIN)-simulator
DEVICE_SDK    := $(shell DEVELOPER_DIR=$(DEVELOPER_DIR) xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK       := $(shell DEVELOPER_DIR=$(DEVELOPER_DIR) xcrun --sdk iphonesimulator --show-sdk-path)

# SwiftPM 6.4 (swift-build backend) puts products here rather than .build/<triple>/release.
DEVICE_BIN := .build/out/Products/Release-iphoneos/$(APP)
SIM_BIN    := .build/out/Products/Release-iphonesimulator/$(APP)
DEVICE_APP := build/device/Payload/$(APP).app
SIM_APP    := build/sim/$(APP).app
IPA        := build/$(APP).ipa

.PHONY: all build build-sim bundle bundle-sim ipa sim release icon clean

all: ipa

build:
	swift build -c release --triple $(DEVICE_TRIPLE) --sdk $(DEVICE_SDK)

build-sim:
	swift build -c release --triple $(SIM_TRIPLE) --sdk $(SIM_SDK)

# iOS bundles are flat: binary, Info.plist and icons sit at the top level of the .app.
# Stamps VERSION/BUILD into the bundled plist when set, never into the source plist.
define ASSEMBLE
rm -rf $(1) && mkdir -p $(1)
cp $(2) $(1)/$(APP)
cp Resources/Info.plist $(1)/Info.plist
cp Resources/Icons/*.png $(1)/
if [ -n "$(VERSION)" ]; then plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(1)/Info.plist; fi
if [ -n "$(BUILD)" ]; then plutil -replace CFBundleVersion -string "$(BUILD)" $(1)/Info.plist; fi
endef

bundle: build
	$(call ASSEMBLE,$(DEVICE_APP),$(DEVICE_BIN))

bundle-sim: build-sim
	$(call ASSEMBLE,$(SIM_APP),$(SIM_BIN))
	codesign --force --sign - $(SIM_APP)

# Left unsigned on purpose. iPhones reject ad-hoc signatures, so SideStore signs this
# on the phone with the free Personal Team certificate.
ipa: bundle
	rm -f $(IPA)
	cd build/device && zip -qr ../$(APP).ipa Payload
	@echo "Built $(IPA)"

sim: bundle-sim
	xcrun simctl boot "$(SIM)" 2>/dev/null || true
	# Xcode 27 ships the simulator UI as DeviceHub.app instead of Simulator.app.
	# simctl works headless either way, so a missing UI app is not fatal.
	open -a Simulator 2>/dev/null || open "$(DEVELOPER_DIR)/../Applications/DeviceHub.app" 2>/dev/null || true
	xcrun simctl install "$(SIM)" $(SIM_APP)
	xcrun simctl launch "$(SIM)" $(BUNDLE_ID)

# Build, publish a GitHub Release with the IPA, and update source.json for SideStore.
release:
	scripts/release.sh

# Regenerate the placeholder icon and its home screen sizes.
icon:
	swift scripts/make-icon.swift Resources/AppIcon.png
	sips -z 120 120 Resources/AppIcon.png --out Resources/Icons/AppIcon60x60@2x.png >/dev/null
	sips -z 180 180 Resources/AppIcon.png --out Resources/Icons/AppIcon60x60@3x.png >/dev/null

clean:
	rm -rf .build build
