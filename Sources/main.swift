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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt for Accessibility permission if not yet granted.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "TeamsMute")
        }

        let menu = NSMenu()
        let info = NSMenuItem(title: "Hotkey: \u{2318}\u{21E7}M \u{2192} Teams mute", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(NSMenuItem(title: "Toggle mute now", action: #selector(sendMuteToggle), keyEquivalent: ""))
        pttMenuItem = NSMenuItem(title: "Push-to-talk mode (hold to talk)", action: #selector(togglePTT), keyEquivalent: "")
        pttMenuItem.state = pushToTalk ? .on : .off
        menu.addItem(pttMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings\u{2026}", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit TeamsMute", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
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
        sendMuteToggle()
    }

    fileprivate func hotKeyUp() {
        hotKeyIsDown = false
        if pushToTalk { sendMuteToggle() }
    }

    @objc private func togglePTT() {
        pushToTalk.toggle()
        pttMenuItem.state = pushToTalk ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc fileprivate func sendMuteToggle() {
        let teams = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.teams2").first
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.teams").first
        guard let teams else {
            flashStatus(symbol: "exclamationmark.circle")
            return
        }
        let pid = teams.processIdentifier
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: false) else { return }
        down.flags = [.maskCommand, .maskShift]
        up.flags = [.maskCommand, .maskShift]
        down.postToPid(pid)
        up.postToPid(pid)
        flashStatus(symbol: "mic.circle.fill")
    }

    private func flashStatus(symbol: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.statusItem.button?.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "TeamsMute")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
