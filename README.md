[![license](https://img.shields.io/github/license/AminBhst/brisk)](https://github.com/AminBhst/brisk/blob/main/LICENSE)
[![release](https://img.shields.io/github/v/release/AminBhst/brisk)](https://github.com/AminBhst/brisk/releases)
![Downloads](https://img.shields.io/github/downloads/AminBhst/brisk/total.svg)
[![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20MacOS-blue)]()
<p align="center">
<img width="100" src="assets/icons/logo.png" alt="Brisk">
<p align="center"> Fast, multithreaded, cross-platform download manager</pal>
</p>

## :package: Download

Installation files for Windows and Linux are available at [Github Releases](https://github.com/AminBhst/brisk/releases/).

For Linux, make sure to read the [Linux Prerequisites](#linux-prerequisites)


Brisk is also available on the [Arch AUR](https://aur.archlinux.org/packages/brisk-bin) (v1.4.6)

## Linux Prerequisites

### keybinder-3
- Debian/Ubuntu : ```libkeybinder-3.0-0```
- Fedora/RHEL/CentOS : ```keybinder3```
- Arch Linux : ```libkeybinder3```

### appindicator3-0.1
- Debian/Ubuntu : ```libayatana-appindicator3-dev```
- Fedora/RHEL/CentOS : ```libayatana-appindicator-gtk3```
- Arch Linux : ```libappindicator-gtk3```

## :rocket: Key Features

- [Powerful Download Engine](#brisks-download-engine)
- [Browser Integration](#browser-integration)
- Download Queues
- Hotkey (ctrl+alt+A) to quickly add a download URL from the clipboard

## :gear: Brisk's Download Engine
Brisk Download Manager is powered by a high-performance engine that delivers the highest possible download speed across the entire duration of the download.

The key features of the engine include:
- **Dynamic Connection Spawn:** Downloads begin with a single connection, with more connections dynamically added on the fly.
- **Dynamic Connection Reuse:** Completed connections are reassigned to assist other active connections, maintaining the maximum number of concurrent connections to maintaining the highest possible download speed.
- **Smart connection reset:** No connections will be left hanging.

## :globe_with_meridians: Browser Integration
Brisk supports [Browser Integration](https://github.com/AminBhst/brisk-browser-extension) that allows for capturing downloads from the browser and adding them directly into the app.

### Installing The Browser Extension
#### Chrome / Edge / Opera
[link-chrome]: https://github.com/AminBhst/brisk-browser-extension/releases/latest 'Version published on Chrome Web Store'

[<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/chrome/chrome.svg" width="48" alt="Chrome" valign="middle">][link-chrome] [<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/edge/edge.svg" width="48" alt="Edge" valign="middle">][link-chrome] [<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/opera/opera.svg" width="48" alt="Opera" valign="middle">][link-chrome]

#### Firefox
[link-firefox]: https://addons.mozilla.org/en-US/firefox/addon/brisk/

[<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/firefox/firefox.svg" width="48" alt="Firefox" valign="middle">][link-firefox]

## Demo With Browser Integration

<img align="center" width="850" src="assets/Brisk-Demo.gif">

## :hammer_and_wrench: Build From Source

Download the Flutter SDK v2.22.0 and set the path variable

```bash
flutter build macos|windows|linux
```

If you have a feature request, please open an issue and explain it in details.

## :heart: Credits
- GitHub Actions : [AliML111](https://github.com/AliML111)
