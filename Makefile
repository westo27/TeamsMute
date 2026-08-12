APP     = TeamsMute
BUNDLE  = build/$(APP).app

.PHONY: build install clean

build:
	mkdir -p $(BUNDLE)/Contents/MacOS
	swiftc -O Sources/main.swift -o $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/
	codesign --force --sign - $(BUNDLE)

install: build
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	@echo "Installed. Launch it, then grant Accessibility permission when prompted."

clean:
	rm -rf build
