APP     = Hushkey
BUNDLE  = build/$(APP).app

.PHONY: build install clean

build:
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	swiftc -O Sources/main.swift -o $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/
	cp assets/AppIcon.icns $(BUNDLE)/Contents/Resources/
	codesign --force --sign - --identifier com.westo27.hushkey \
		-r='designated => identifier "com.westo27.hushkey"' $(BUNDLE)

install: build
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	@echo "Installed. Launch it, then grant Accessibility permission when prompted."

clean:
	rm -rf build
