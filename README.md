# Stage

Stage plays your own videos on USB-C glasses. The phone is the remote. The glasses are an external display, and AirPods motion keeps the screen pinned while you look around.

Plug the glasses into the iPhone. Until they connect, playback fills the phone and the glasses mirror that picture. With the glasses connected, the phone shows the remote and the picture moves to the glasses.

## Screen

Three modes:

- **Pin** locks the screen in the room.
- **Follow** keeps it in front of you.
- **Drift** leaves it where you put it, then eases it back.

**Recenter** puts the screen back in front of you. Tuning (the sliders button) adjusts size, horizon leveling, axis inversion, prediction, and smoothing.

Head tracking uses AirPods motion. Connect a pair that supports it, and allow motion access when iOS asks. Without that, the screen stays fixed.

## Library

Add a video from Files, Photos, or a direct `http` or `https` link to an MP4 or HLS stream. Progress is saved on the phone. Remove an item from its context menu.

Apple TV, Netflix, YouTube, and Safari can be opened as a normal glasses mirror. Stage cannot see those pictures, so Pin, Follow, and Drift pause until you come back.

## Requirements

- iPhone on iOS 26
- USB-C glasses that connect as an external display
- AirPods with headphone motion, for head tracking

## Install from GitHub

This repo builds an unsigned `Stage.ipa` on a GitHub-hosted Mac. Sideloadly signs it with your Apple ID and installs it. A current Mac with Xcode is not required.

1. Push to `main`. The [iOS workflow](.github/workflows/ios.yml) also runs from **Actions → iOS → Run workflow**.
2. Open the finished run and download the **Stage-ipa** artifact.
3. Unzip it and keep `Stage.ipa`.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode**, then restart and confirm.
5. Install the current [Sideloadly](https://sideloadly.io) on a computer that can see the phone. Use a data cable, and tap **Trust This Computer**. If the Mac is too old for Finder to see the iPhone, use Sideloadly on a Windows PC with the Apple Devices app installed.
6. Drag `Stage.ipa` into Sideloadly, enter your Apple ID, and start the install.
7. If the app will not open, go to **Settings → General → VPN & Device Management**, select your Apple ID, and tap Trust.

A free Apple ID signature lasts 7 days. Plug the phone back in and install the same IPA again when it expires. A paid Apple Developer account lasts about a year. You only need a new GitHub build when the code changes.

## Build locally

Local builds need Xcode 26 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
bash scripts/build-ipa.sh
```

The script generates `Stage.xcodeproj`, compiles the `Stage` scheme for iOS without signing, and writes `Stage.ipa`. The Xcode project and the IPA are gitignored. `project.yml` is the project definition.

Open the generated project in Xcode if you want to run it on a device from a Mac that can sign the app.
