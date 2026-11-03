# TahoeLaunchpad (CLauncher) 🚀

A modern, fluid, next-generation macOS Launchpad designed with macOS Tahoe Liquid Glass aesthetics, 120Hz ProMotion display-link acceleration, zero-latency search, and Apple HIG drag-and-drop physics.

![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Features

- **Liquid Glass Aesthetics:** Native macOS translucent materials (`.ultraThinMaterial`), authentic vibrancy blending directly from the user's desktop wallpaper, and specular micro-stroke rims.
- **120Hz ProMotion Continuous Physics:** WindowServer variable refresh rate locked at 80–120Hz via `CADisplayLink` during all interactions (scrolling, swiping, dragging, folder transitions).
- **Apple HIG Drag & Drop Experience:**
  - **Hold-to-Merge (Dwell Timer 0.35s):** Dragging an app over another app and pausing for 0.35s triggers folder creation with haptic feedback and frosted glass focus ring. Quick drag-past immediately reorders slots.
  - **Frictionless Folder Reordering:** Moving folders on the main grid is instant and buttery-smooth without nesting collisions.
- **Atomic Data Safety:** Robust layout persistence with zero lost apps across multi-page grids and folder extractions.
- **Zero-CPU Idle Footprint:** 0.0% CPU usage when idle; fully event-driven architecture.
- **Persistent GPU Icon Cache:** High-capacity RAM cache keeping up to 256 app icons in Metal-ready texture format for instantaneous, stutter-free window opening.
- **Smart Fuzzy Search:** Instant keyboard navigation and app launching via search bar.
- **Global Hotkeys:** Quick toggle using `Option + Space` or `F4`, plus Status Bar icon.

---

## 🛠️ Building & Packaging

### Prerequisites
- macOS 14.0 (Sonoma) or newer (macOS 15 Sequoia / macOS Tahoe ready)
- Xcode 15+ or Swift 6.0 toolchain

### Build Release App Bundle
```bash
./build_app.sh
```
This generates `Launchpad.app` in the root directory.

### Build Installer DMG
```bash
./build_dmg.sh
```
This packages and compresses `Launchpad.app` into `Launchpad-2.0.0.dmg` with `/Applications` shortcut and custom Finder layout.

---

## ⌨️ Shortcuts & Gestures

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Toggle Launchpad** | `Option + Space` or `F4` |
| **Dismiss** | `Escape` or click empty background |
| **Next / Previous Page** | Swipe 2 fingers, Arrow keys `←` / `→`, or Page dots |
| **Move Item** | Click & drag icon to any slot |
| **Create Folder** | Drag app over another app and hold for 0.35s |
| **Extract from Folder** | Drag app outside folder window onto backdrop |

---

## 📄 License

This project is licensed under the MIT License.
