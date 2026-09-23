# Smitch Offline — Local Smart Home Controller (Fixed Cloud Shutdown)

[![Release](https://img.shields.io/badge/Release-v2.2.2--offline-blue.svg)](https://github.com/ak-ag/smitch-offline/releases)
[![Android](https://img.shields.io/badge/Platform-Android-green.svg)](https://github.com/ak-ag/smitch-offline)
[![YouTube](https://img.shields.io/badge/YouTube-Watch%20Demo-red.svg?logo=youtube)](https://youtube.com/shorts/azQOjrDOdtY?feature=share)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Author](https://img.shields.io/badge/Modified%20by-ak--ag-purple.svg)](https://github.com/ak-ag)

> **Revive your Smitch devices!** Smitch smart home cloud servers permanently ceased operations, rendering the official Android app and cloud features unusable (causing *"No internet connection"* or login failures). This repository provides a **fully patched, signed Android APK** and open-source patcher that bypasses all dead cloud endpoints, unlocking **direct local Wi-Fi TCP/UDP socket control** for Smitch RGB Smart Bulbs, smart plugs, and switchboards.

---

## 📺 Video Demonstration

Watch the live demonstration showing offline pairing, connection, and RGB color control of a Smitch Smart Bulb:

[![Smitch Offline YouTube Demo](https://img.shields.io/badge/YouTube%20Shorts-Watch%20Live%20Demo-red?style=for-the-badge&logo=youtube)](https://youtube.com/shorts/azQOjrDOdtY?feature=share)

▶️ **Watch on YouTube:** [https://youtube.com/shorts/azQOjrDOdtY](https://youtube.com/shorts/azQOjrDOdtY?feature=share)

*(You can also download or view the high-definition recording directly from this repository: [`demo_recording.mp4`](demo_recording.mp4))*

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

## ⚠️ Important Usage Notes

- **App Launch Time**: The app may take a moment to initialize on its first run — please be patient while local SQLite tables and background services spin up.
- **Navigation Tip**: If you ever get stuck or cannot navigate back, simply swipe close the app from your phone's **Recent Apps / App Switcher** and reopen it.
- **Wi-Fi Network Compatibility**: Smitch hardware microcontrollers exclusively communicate over **2.4 GHz Wi-Fi** (802.11 b/g/n). 5 GHz-only Wi-Fi networks will not connect.
- **Bulb Wi-Fi Visibility**:
  - When the bulb is turned on, its setup Wi-Fi network (`Smitch_v1...`) should appear in your phone's Wi-Fi settings.
  - **If the hotspot is NOT visible**: Reset the bulb by toggling the physical wall switch **OFF and ON 5 to 8 times** with a **2-second gap** between each switch until the bulb flashes rapidly, then check your phone's Wi-Fi list again.
  - **Previously Connected Bulbs**: If your bulb was already connected to your home Wi-Fi, it will not broadcast its setup hotspot. In that case, follow the **Factory Reset Steps** below to reset and re-detect it.

---

## 🔄 Step-by-Step Setup & Factory Reset Guide

Follow these exact steps if setting up a new bulb or recovering an existing bulb:

1. **Open the Smitch app**:
   - Tap the **`+` (Plus)** button on the top right.
   - If a confirmation dialog appears asking to search for another bulb, tap **"Search"**.
   - You should now see the **`WELCOME TO SMITCH`** screen.
2. **Tap the Right Arrow (`→`)** at the bottom to proceed to device selection.
3. **Select Product**:
   - Tap on the **Smart Bulb** icon.
   - Tap **Next**.
4. **Tap Next again** on the setup preparation screen.
5. **Start Configuration**:
   - The app will display *"Start configuration"* and attempt to locate your device.
   - **If found**: You will see the connection method screen &rarr; select **"Connect directly"**.
6. **If NOT found**:
   - Tap the **Settings Gear (⚙️)** on the top right of the configuration screen.
   - Scroll down to the **"Factory Reset Device"** option.
   - Try **both methods**:
     - **Method 1**: Smitch Wi-Fi Connection (connect to the bulb's direct hotspot).
     - **Method 2**: Home Wi-Fi Connection (if bulb is already attached to your router).

---

## 💡 How the Offline Patch Works

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

## 🛡️ Attribution & Notice

- **Modified & Maintained by**: [@ak-ag](https://github.com/ak-ag)
- **Original Software**: Smitch (MySmitch Technologies Pvt Ltd). This project is an independent community rescue patch created after official cloud servers went offline, intended solely for device interoperability and electronic waste prevention.
- If you find this helpful, please star ⭐ the repo so other Smitch owners can find and reuse their hardware!
