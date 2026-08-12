# Hushkey

A minimal macOS menu-bar utility that gives Microsoft Teams a **global mute hotkey** (⌘⇧M) and an optional **push-to-talk mode** — working even when Teams is in the background.

## Why

In 2026 Microsoft retired the legacy "third-party app API" in the Teams desktop client (message centre MC1266901, effective 30 June 2026). That local WebSocket API was what mute-button apps and hardware (Muteem, MuteDeck, Stream Deck plugins, and others) relied on, and current Teams builds no longer ship it — the "Third-party app API" toggle is gone from Teams' privacy settings entirely.

Hushkey takes a different approach that does not depend on any Teams API: it registers a system-wide hotkey and injects Teams' own in-app mute shortcut (⌘⇧M) directly into the Teams process via `CGEventPostToPid()`. Microsoft cannot retire that without removing their own keyboard shortcut.

## Features

- Global ⌘⇧M — toggles Teams mute from any app, without switching windows.
- Push-to-talk mode — hold ⌘⇧M to talk, release to re-mute (toggle in the menu).
- "Toggle mute now" menu item.
- No configuration, no pairing, no tokens, no network access whatsoever.

## Install

Build from source (requires Xcode Command Line Tools):

```sh
make install
```

This compiles the app, ad-hoc signs it, and copies it to `/Applications`. Launch it, then grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility) — required to send keystrokes to Teams. Add it to Login Items if you want it always available.

If you download a pre-built release instead of compiling, macOS Gatekeeper will block the unsigned app on first launch: right-click → Open → Open.

## Limitations

- **No mute-state indicator.** Reading the actual mute state was only possible via the retired API. Hushkey sends the toggle blind; check the Teams window for current state. (Reading state from the Accessibility tree is a possible future feature.)
- Only effective while you are in a Teams call — outside calls, Teams ignores the shortcut.
- The hotkey captures ⌘⇧M system-wide, shadowing that combination in other apps.
- Assumes the new Teams client (`com.microsoft.teams2`), with fallback to classic Teams.

## Licence

[MIT](LICENSE)
