# Smitch Offline — Local Smart Home Controller (Fixed Cloud Shutdown)

[![Release](https://img.shields.io/badge/Release-v2.2.2--offline-blue.svg)](https://github.com/ak-ag/smitch-offline/releases)
[![Android](https://img.shields.io/badge/Platform-Android-green.svg)](https://github.com/ak-ag/smitch-offline)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Author](https://img.shields.io/badge/Modified%20by-ak--ag-purple.svg)](https://github.com/ak-ag)

> **Revive your Smitch devices!** Smitch smart home cloud servers permanently ceased operations, rendering the official Android app and cloud features unusable (causing *"No internet connection"* or login failures). This repository provides a **fully patched, signed Android APK** and open-source patcher that bypasses all dead cloud endpoints, unlocking **direct local Wi-Fi TCP/UDP socket control** for Smitch RGB Smart Bulbs, smart plugs, and switchboards.

---

## 📺 Video Demonstration

A full demonstration showing live offline connection and color control of a Smitch RGB Bulb:

![Smitch Demo Video](demo_recording.mp4)

*(Click to view or play the attached [`demo_recording.mp4`](demo_recording.mp4) video)*

---

## 🌟 Key Features

- **No Cloud Required**: Works 100% locally on your home Wi-Fi network without relying on defunct Smitch servers.
- **Direct TCP Socket Control (Port 80)**: Communicates directly with the ESP-based microcontrollers in Smitch devices using native local socket payloads.
- **ZeroConf / mDNS Device Discovery**: Automatically scans and monitors local Smitch devices (`_http._tcp.local.`).
- **Full Smart Bulb Control**:
  - Instant Power Toggle (On / Off).
  - Full RGB color wheel with live color adjustments.
  - Smooth Brightness slider (10% - 100%).
  - Built-in dynamic effects (Randomize, Candle, Strobe).
- **Multi-Device Navigation**:
  - **Home Dashboard Button**: Quickly return to the main offline device management screen.
  - **Search / Add Another Bulb**: Switch or pair additional bulbs seamlessly without app lockouts.
  - **Quick Bulb Return**: Jump right back into active bulb control from the offline dashboard.
- **Signed & Ready to Install**: Signed with v1, v2, and v3 Android APK signature schemes, zip-aligned, and compatible with modern Android versions (Android 8 through Android 15+).

---

## 📥 Download & Installation

### Option 1: Direct APK Download (Recommended)
1. Download the latest signed APK:
   👉 **[`smitch_offline.apk`](smitch_offline.apk)** (or from the [Releases](https://github.com/ak-ag/smitch-offline/releases) tab).
2. **Uninstall any previous Smitch app** from your Android device first (due to different signing keys).
3. Transfer the APK to your phone and install it (allow *"Install unknown apps"* if prompted).
4. Connect your phone to your 2.4 GHz home Wi-Fi network (or the bulb's direct hotspot during pairing).
5. Open **Smitch** — you will immediately enter the offline dashboard with full local control.

### Option 2: Install via ADB (For Developers)
```bash
adb uninstall com.mysmitch.android
adb install -r smitch_offline.apk
adb shell am start -n com.mysmitch.android/.MainActivity
```

---

## 💡 How It Works

When Smitch servers shut down, the original application failed at startup because:
1. `landCtrl` tried to validate credentials against dead REST endpoints (`52.86.34.244` / `api.mysmitch.com`).
2. Cloud onboarding routines crashed when MQTT / HTTP cloud handshakes timed out.

### The Fix:
- **Offline Controller Routing**: Patched `landCtrl` and `Page1Ctrl` to default directly to local SQLite storage and route straight to `onboard_lite` and `offline` state machines.
- **Local Hotspot & ZeroConf Handshake**: Patched `after_onlineconfig` to read device IP and state directly from local TCP socket data (`0001xx...`), bypassing cloud device provisioning entirely.
- **Persistent Local Navigation**: Added back-navigation and device reset hooks to prevent users from getting trapped on a single device screen.

---

## 🛠️ Build from Source

If you want to inspect or build the patch yourself:

### Prerequisites
- Windows PowerShell 5.1+
- Java JRE/JDK 8+
- [Node.js](https://nodejs.org/) (for syntax verification)

### Steps
1. Clone this repository:
   ```bash
   git clone https://github.com/ak-ag/smitch-offline.git
   cd smitch-offline
   ```
2. Run the automated patch & build script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\patch_smitch_offline.ps1
   ```
3. The script will:
   - Decompile and patch `app.js` and HTML templates.
   - Run automated syntax validation with `node -c`.
   - Recompile the APK using Apktool.
   - Sign and zipalign the APK using `uber-apk-signer` (v1/v2/v3 signatures).
   - Generate `smitch_offline.apk`.

---

## ❓ Troubleshooting & Tips

- **Bulb Not Detected?**
  - Reset your Smitch bulb into pairing mode (power cycle the wall switch On-Off-On-Off-On until the bulb rapidly flashes).
  - Connect your phone to the bulb's Wi-Fi hotspot (`Smitch_v1...`).
  - Open the app, configure your Wi-Fi credentials, and control it directly.
- **App Shows White Screen?**
  - Make sure you uninstalled the older original Smitch app first before installing `smitch_offline.apk`.
- **Router Compatibility**:
  - Smitch smart home hardware only supports **2.4 GHz Wi-Fi** networks (802.11 b/g/n). Ensure your Wi-Fi network has 2.4 GHz enabled.

---

## 🛡️ Attribution & Notice

- **Modified & Maintained by**: [@ak-ag](https://github.com/ak-ag)
- **Original Software**: Smitch (MySmitch Technologies Pvt Ltd). This project is an independent community rescue patch created after official cloud servers went offline, intended solely for device interoperability and electronic waste prevention.
- If you find this helpful, please star ⭐ the repo so other Smitch owners can find and reuse their hardware!
