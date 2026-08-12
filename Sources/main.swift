import Cocoa
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var pttMenuItem: NSMenuItem!
    private var hotKeyIsDown = false

    private var pushToTalk: Bool {
        get { UserDefaults.standard.bool(forKey: "pushToTalk") }
        set { UserDefaults.standard.set(newValue, forKey: "pushToTalk") }
    }

    private var playSounds: Bool {
        get { UserDefaults.standard.bool(forKey: "playSounds") }
        set { UserDefaults.standard.set(newValue, forKey: "playSounds") }
    }

    // Best-effort state tracking: Teams' real mute state is unreadable, so
    // assume "muted" at launch and flip on every toggle we send.
    private var presumedMuted = true
    private var soundsMenuItem: NSMenuItem!

    private var sigusr1Source: DispatchSourceSignal?

    private func debugLog(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/Hushkey.log")
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["playSounds": true])
        // Prompt for Accessibility permission if not yet granted.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        debugLog("launch: axTrusted=\(AXIsProcessTrusted())")

        // Debug trigger: `kill -USR1 <pid>` fires the mute toggle.
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in self?.sendMuteToggle() }
        source.resume()
        sigusr1Source = source

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Hushkey")
        }

        let menu = NSMenu()
        let info = NSMenuItem(title: "Hotkey: \u{2318}\u{21E7}M \u{2192} Teams mute", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(NSMenuItem(title: "Toggle mute now", action: #selector(sendMuteToggle), keyEquivalent: ""))
        pttMenuItem = NSMenuItem(title: "Push-to-talk mode (hold to talk)", action: #selector(togglePTT), keyEquivalent: "")
        pttMenuItem.state = pushToTalk ? .on : .off
        menu.addItem(pttMenuItem)
        soundsMenuItem = NSMenuItem(title: "Play sounds on toggle", action: #selector(toggleSounds), keyEquivalent: "")
        soundsMenuItem.state = playSounds ? .on : .off
        menu.addItem(soundsMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings\u{2026}", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        let quitItem = NSMenuItem(title: "Quit Hushkey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Explicit target: in a windowless accessory app the responder chain
        // does not reliably resolve terminate(_:) for status-bar menus.
        quitItem.target = NSApp
        menu.addItem(quitItem)
        menu.items.filter { $0 !== quitItem }.forEach { $0.target = self }
        statusItem.menu = menu

        registerHotKey()
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x54_4D_55_54), id: 1) // 'TMUT'
        RegisterEventHotKey(UInt32(kVK_ANSI_M),
                            UInt32(cmdKey | shiftKey),
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)

        let specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            switch GetEventKind(event) {
            case UInt32(kEventHotKeyPressed): delegate.hotKeyDown()
            case UInt32(kEventHotKeyReleased): delegate.hotKeyUp()
            default: break
            }
            return noErr
        }, specs.count, specs, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    fileprivate func hotKeyDown() {
        guard !hotKeyIsDown else { return } // ignore key-repeat
        hotKeyIsDown = true
        // In push-to-talk the direction is known: key down means unmute.
        performToggle(setMutedTo: pushToTalk ? false : nil)
    }

    fileprivate func hotKeyUp() {
        hotKeyIsDown = false
        if pushToTalk { performToggle(setMutedTo: true) }
    }

    @objc private func togglePTT() {
        pushToTalk.toggle()
        pttMenuItem.state = pushToTalk ? .on : .off
    }

    @objc private func toggleSounds() {
        playSounds.toggle()
        soundsMenuItem.state = playSounds ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private var hasWarnedNotTrusted = false

    @objc fileprivate func sendMuteToggle() {
        performToggle(setMutedTo: nil)
    }

    private func performToggle(setMutedTo: Bool?) {
        guard AXIsProcessTrusted() else {
            debugLog("send: blocked, Accessibility not granted")
            flashStatus(symbol: "exclamationmark.triangle")
            if !hasWarnedNotTrusted {
                hasWarnedNotTrusted = true
                openAccessibilitySettings()
            }
            return
        }
        let teams = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.teams2").first
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.teams").first
        guard let teams else {
            debugLog("send: Teams not running")
            flashStatus(symbol: "exclamationmark.circle")
            return
        }
        let pid = teams.processIdentifier
        debugLog("send: axTrusted=\(AXIsProcessTrusted()) teamsPid=\(pid) bundle=\(teams.bundleIdentifier ?? "?")")
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: false) else { return }
        down.flags = [.maskCommand, .maskShift]
        up.flags = [.maskCommand, .maskShift]
        down.postToPid(pid)
        up.postToPid(pid)
        presumedMuted = setMutedTo ?? !presumedMuted
        if playSounds {
            NSSound(named: presumedMuted ? "Pop" : "Tink")?.play()
        }
        flashStatus(symbol: "mic.circle.fill")
    }

    private func flashStatus(symbol: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.statusItem.button?.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Hushkey")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
