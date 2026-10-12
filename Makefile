APP_NAME := Lugbara
APP := build/$(APP_NAME).app
BUNDLE_ID := io.plenora.lugbara
INSTALL_DIR := /Applications
# Signing every build with the same certificate keeps the app's identity stable, so macOS
# remembers the Accessibility and keychain permissions. Create it with scripts/create-signing-certificate.sh.
# Without it, the app is signed ad hoc and macOS asks for the permissions again after each build.
CERTIFICATE := Lugbara Local
SIGNING_IDENTITY ?= $(shell security find-identity -p codesigning | grep -q '"$(CERTIFICATE)"' && echo '$(CERTIFICATE)' || echo -)

.PHONY: app install run test clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/$(APP_NAME) $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "$(SIGNING_IDENTITY)" --identifier $(BUNDLE_ID) $(APP)

install: app
	-pkill -x $(APP_NAME)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP_NAME).app

run: app
	-pkill -x $(APP_NAME)
	open $(APP)

test:
	swift test

clean:
	rm -rf .build build
