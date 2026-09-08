# Release build configuration
APP     = ".build/FuelSwitch AI.app"
DIST    = .build/dist
DMG     = .build/FuelSwitch-AI.dmg
ZIP     = .build/FuelSwitch-AI.zip
DMG_RW  = .build/fuelswitch-rw.dmg
MOUNT   = .build/mnt

# Release signing. Set TEAM_ID and SIGN_ID to your own Developer ID credentials.
TEAM_ID ?= YOUR_TEAM_ID
SIGN_ID ?= Developer ID Application ($(TEAM_ID))

# Local-only secrets (Gemini OAuth client, etc) live in .env, gitignored, one
# key-value pair per line. Every recipe that builds or runs the app sources it
# first so FUELSWITCH_GEMINI_CLIENT_ID/SECRET reach the process environment.
ifneq (,$(wildcard .env))
include .env
export
endif

# Credentials for notarytool:
NOTARY_PROFILE ?= fuelswitch-notary

.PHONY: app run test clean bundle icon sign staple dmg notarize release

test:
	swift test

# Ad-hoc signed: fine on this machine, refused as "unidentified developer"
# anywhere else. That is what `release` is for.
app: bundle
	codesign --force --sign - $(APP)
	@echo "Built $(APP) (ad-hoc signed, this machine only)"

# Universal binary: SwiftPM emits a lipo'd fat executable to
# .build/apple/Products/Release when given two --arch flags. A plain
# "swift build -c release" only produces this machine's own arch, which
# macOS refuses to launch at all on the other CPU family ("this app is
# not supported on this device" — an architecture mismatch, not an OS one).
bundle: icon
	swift build -c release --arch arm64 --arch x86_64
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp .build/apple/Products/Release/FuelSwitch $(APP)/Contents/MacOS/FuelSwitch

# The icon is drawn from code rather than stored as a binary nobody can edit.
icon: Resources/AppIcon.icns
Resources/AppIcon.icns: Tools/make-icon.swift
	swift Tools/make-icon.swift $@

# Hardened runtime and a secure timestamp are both required before Apple will
# notarize anything.
sign: bundle
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $(APP)
	codesign --verify --strict --verbose=2 $(APP)
	@echo "Signed with Developer ID"

# The app gets a notarisation ticket of its own, stapled into the bundle. The
# DMG is notarised separately further down; only the app's own ticket survives
# being dragged out of the disk image, and it is what lets a first launch work
# without a network connection.
staple: sign
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	xcrun notarytool submit $(ZIP) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(APP)
	rm -f $(ZIP)

# ditto rather than cp, because the ticket stapler just wrote is an extended
# attribute; validate proves it survived the copy.
dmg: staple
	rm -rf $(DIST) $(DMG)
	mkdir -p $(DIST)
	ditto $(APP) "$(DIST)/FuelSwitch AI.app"
	xcrun stapler validate "$(DIST)/FuelSwitch AI.app"
	ln -s /Applications $(DIST)/Applications
	cp Resources/AppIcon.icns $(DIST)/.VolumeIcon.icns
	# The custom icon bit lives on the volume and can only be set while the
	# volume is writable, so the image is built read-write, stamped, and only
	# then compressed. Without it the disk image shows the generic one.
	rm -f $(DMG_RW); rm -rf $(MOUNT)
	hdiutil create -volname "FuelSwitch AI" -srcfolder $(DIST) -ov -format UDRW $(DMG_RW)
	mkdir -p $(MOUNT)
	hdiutil attach $(DMG_RW) -mountpoint $(MOUNT) -nobrowse -quiet
	SetFile -a C $(MOUNT)
	hdiutil detach $(MOUNT) -quiet
	rmdir $(MOUNT)
	hdiutil convert $(DMG_RW) -format UDZO -o $(DMG)
	rm -f $(DMG_RW)
	codesign --force --timestamp --sign "$(SIGN_ID)" $(DMG)

# An unsigned disk image has nothing for spctl to assess, however well notarised
# its contents are — hence the codesign above before this ticket is fetched.
notarize: dmg
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)
	spctl --assess --type open --context context:primary-signature -v $(DMG)
	spctl --assess --type execute -v $(APP)
	@echo "Notarised and stapled: $(DMG)"

release: notarize

run: app
	open $(APP)

clean:
	rm -rf .build
