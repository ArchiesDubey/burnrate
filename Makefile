# Default to standard Xcode location only if it exists and the user hasn't
# already chosen a toolchain via `sudo xcode-select -s` / $DEVELOPER_DIR.
# Unconditionally exporting a path that doesn't exist breaks `make` on machines
# with only the Command Line Tools installed (xcrun: missing DEVELOPER_DIR).
ifeq (,$(DEVELOPER_DIR))
ifneq (,$(wildcard /Applications/Xcode.app/Contents/Developer))
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif
endif

PROJECT := Burnrate.xcodeproj
SCHEME  := Burnrate
DEST    := platform=macOS,arch=arm64

# Debug builds are ad-hoc signed so anyone can build without the maintainer's
# Developer ID certificate (see CONTRIBUTING.md). Release (archive below) keeps
# the Developer ID identity for notarization + Sparkle.
DEV_SIGN := CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Automatic

# Override the deployment target for this invocation only, for developing on a
# host older than the shipped floor — e.g. on a Mac still running macOS 15:
#
#     make test DEPLOYMENT_TARGET=15.0
#
# This changes what runs on YOUR machine, not what ships: the product's floor
# stays in project.yml (deploymentTarget) until deliberately lowered there.
DEPLOYMENT_TARGET ?=
DEPLOY_ARGS = $(if $(DEPLOYMENT_TARGET),MACOSX_DEPLOYMENT_TARGET=$(DEPLOYMENT_TARGET))

.PHONY: gen build test run install clean

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Debug $(DEV_SIGN) $(DEPLOY_ARGS) build

test: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Debug $(DEV_SIGN) $(DEPLOY_ARGS) test

run: build
	@APP=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Debug -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2; exit}')/Burnrate.app; \
	pkill -x Burnrate || true; \
	open "$$APP"

# The normal-app path: build, put it in /Applications, launch it. After the
# first `make install`, the app is an ordinary Mac app — Spotlight, Dock,
# Launch at Login (Settings toggle) all work, and it survives reboots.
# Re-run after pulling changes to update the installed copy.
#
# Ad-hoc signing means every install is a new identity to macOS, so the
# keychain asks once per install (not per launch) for borrowed credentials;
# that stops when a Developer ID signs real releases.
install: build
	@APP=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Debug -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2; exit}')/Burnrate.app; \
	pkill -x Burnrate || true; \
	rm -rf /Applications/Burnrate.app; \
	cp -R "$$APP" /Applications/ && \
	echo "Installed /Applications/Burnrate.app" && \
	xattr -dr com.apple.quarantine /Applications/Burnrate.app || true; \
	open /Applications/Burnrate.app

clean:
	rm -rf build DerivedData $(PROJECT)

# --- Release -----------------------------------------------------------------
# The path to a notarized .dmg. Run `make release` for the whole thing, or the
# steps one at a time while something is going wrong.
#
# One-time setup, which you have to run yourself because it takes a password:
#
#   xcrun notarytool store-credentials $(NOTARY_PROFILE) \
#       --apple-id <your-apple-id> --team-id $(SIGNING_TEAM) --password <app-specific-password>
#
# The app-specific password comes from appleid.apple.com → Sign-In and Security
# → App-Specific Passwords. Not your Apple ID password.
#
# Both variables are overridable so CI can inject them from secrets:
#   make notarize NOTARY_PROFILE=ci-notary SIGNING_TEAM=XXXXXXXXXX

RELEASE_DIR := build/release
APP_NAME    := Burnrate
# The label of the stored notarytool credential in the login keychain.
NOTARY_PROFILE ?= burnrate-notary
# The Apple Developer team whose Developer ID certificate signs the release.
# Empty until the org account exists; `make archive` will say so if asked to
# export without it.
SIGNING_TEAM ?=
DMG := $(RELEASE_DIR)/$(APP_NAME).dmg

.PHONY: archive dmg notarize release verify-release

# Release configuration, exported with the Developer ID identity. `xcodebuild
# archive` + `-exportArchive` rather than a plain build: it re-signs the bundle
# as a distributable, which a Debug build is not.
archive: gen
	@test -n "$(SIGNING_TEAM)" || (echo "SIGNING_TEAM is empty — set it to your Apple Developer team ID, e.g. make archive SIGNING_TEAM=XXXXXXXXXX" && exit 1)
	rm -rf $(RELEASE_DIR)
	mkdir -p $(RELEASE_DIR)
	@# Spotlight indexes build output as installed applications, so every
	@# release leaves extra "Burnrate" entries in app search next to the
	@# real one in /Applications. This stops the whole tree being indexed.
	@touch build/.metadata_never_index
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-configuration Release -archivePath $(RELEASE_DIR)/$(APP_NAME).xcarchive archive
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0"><dict>' \
		'<key>method</key><string>developer-id</string>' \
		'<key>teamID</key><string>$(SIGNING_TEAM)</string>' \
		'<key>signingStyle</key><string>manual</string>' \
		'<key>signingCertificate</key><string>Developer ID Application</string>' \
		'</dict></plist>' > $(RELEASE_DIR)/ExportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(RELEASE_DIR)/$(APP_NAME).xcarchive \
		-exportOptionsPlist $(RELEASE_DIR)/ExportOptions.plist \
		-exportPath $(RELEASE_DIR)

# A plain drag-to-Applications disk image. `hdiutil` writes it read-only and
# compressed, which is what notarization expects.
dmg: archive
	rm -f $(DMG)
	rm -rf $(RELEASE_DIR)/stage
	mkdir -p $(RELEASE_DIR)/stage
	cp -R $(RELEASE_DIR)/$(APP_NAME).app $(RELEASE_DIR)/stage/
	ln -s /Applications $(RELEASE_DIR)/stage/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(RELEASE_DIR)/stage \
		-ov -format UDZO $(DMG)
	codesign --force --sign "Developer ID Application" --timestamp $(DMG)
	@# The app is inside the dmg now. Leaving the loose copies around is how
	@# three spare "Burnrate" entries end up in Spotlight; everything
	@# downstream (notarize, verify, appcast) works from the dmg alone.
	rm -rf $(RELEASE_DIR)/stage $(RELEASE_DIR)/$(APP_NAME).app

# Submits and waits. `--wait` blocks until Apple answers, which is usually a
# couple of minutes; on rejection, the log says which binary failed and why.
notarize: dmg
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)

# Sparkle ships its tools inside the resolved package artifacts.
SPARKLE_BIN = $(shell dirname $$(find $$HOME/Library/Developer/Xcode/DerivedData/Burnrate-*/SourcePackages/artifacts/sparkle -name generate_appcast 2>/dev/null | head -1))

# The feed customers' copies poll. Signs each update with the EdDSA private key
# in the login keychain — Sparkle installs nothing that key did not sign, so a
# compromised host cannot push code.
#
# Writes into dist/ — point whatever hosts your downloads at it. The enclosure
# URL the appcast advertises has to match where the file actually sits, or an
# update downloads and then fails to verify.
PAGES_DIR := dist
# TODO(owner): the base URL the dmg will be downloadable from once a site
# exists. Only `make appcast` uses it, so an empty placeholder breaks nothing.
DOWNLOAD_PREFIX ?= https://updates.burnrate.invalid/

appcast: $(DMG)
	@test -n "$(SPARKLE_BIN)" || (echo "Sparkle tools not found — run make build first" && exit 1)
	mkdir -p $(PAGES_DIR)
	@# Rebuilt from what is actually in the folder, never merged into the old
	@# one. The dmg keeps a constant name, so only one build can exist at a
	@# time — but generate_appcast preserves entries it already knows, and left
	@# the previous version advertised at a URL now serving a different file,
	@# with a signature that could never verify.
	rm -f $(PAGES_DIR)/appcast.xml
	cp $(DMG) $(PAGES_DIR)/
	$(SPARKLE_BIN)/generate_appcast $(PAGES_DIR) --download-url-prefix $(DOWNLOAD_PREFIX)
	@echo "Publish by committing $(PAGES_DIR)/ and pushing."

release: notarize verify-release appcast
	@echo "Notarized: $(DMG)"

# What Gatekeeper on a customer's Mac will check. `spctl` accepting the app is
# the actual proof that the download will open without a right-click.
verify-release:
	xcrun stapler validate $(DMG)
	hdiutil attach $(DMG) -nobrowse -mountpoint $(RELEASE_DIR)/mnt
	codesign --verify --deep --strict --verbose=2 $(RELEASE_DIR)/mnt/$(APP_NAME).app
	spctl --assess --type execute --verbose=4 $(RELEASE_DIR)/mnt/$(APP_NAME).app
	hdiutil detach $(RELEASE_DIR)/mnt
