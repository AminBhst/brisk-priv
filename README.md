[![license](https://img.shields.io/github/license/AminBhst/brisk)](https://github.com/AminBhst/brisk/blob/main/LICENSE)
[![release](https://img.shields.io/github/v/release/AminBhst/brisk)](https://github.com/AminBhst/brisk/releases)
![Downloads](https://img.shields.io/github/downloads/AminBhst/brisk/total.svg)
[![platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20MacOS-blue)]()
<p align="center">
<img width="100" src="assets/icons/logo.png" alt="Brisk">
<p align="center"> Fast, multithreaded, cross-platform download manager</pal>
</p>

## Download

Installation files for Windows and Linux are available
at [Github Releases](https://github.com/AminBhst/brisk/releases/).

Brisk is also available on the [Arch AUR](https://aur.archlinux.org/packages/brisk-bin)

## Browser Integration
Brisk supports [Browser Integration](https://github.com/AminBhst/brisk-browser-extension) that allows for capturing downloads from the browser and adding them directly into the app.

### Installing The Browser Extension
#### Chrome / Edge / Opera
[link-chrome]: https://github.com/AminBhst/brisk-browser-extension/releases/latest 'Version published on Chrome Web Store'

[<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/chrome/chrome.svg" width="48" alt="Chrome" valign="middle">][link-chrome] [<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/edge/edge.svg" width="48" alt="Edge" valign="middle">][link-chrome] [<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/opera/opera.svg" width="48" alt="Opera" valign="middle">][link-chrome]

#### Firefox
[link-firefox]: https://addons.mozilla.org/en-US/firefox/addon/brisk/

[<img src="https://raw.githubusercontent.com/alrra/browser-logos/90fdf03c/src/firefox/firefox.svg" width="48" alt="Firefox" valign="middle">][link-firefox]
## Linux Prerequisites

### keybinder-3
- Debian/Ubuntu : ```libkeybinder-3.0-0```
- Fedora/RHEL/CentOS : ```keybinder3```
- Arch Linux : ```libkeybinder3```

### appindicator3-0.1
- Debian/Ubuntu : ```libayatana-appindicator3-dev```
- Fedora/RHEL/CentOS : ```libayatana-appindicator-gtk3```
- Arch Linux : ```libappindicator-gtk3```

## Features

- Browser Integration
- Multi-segment file downloading
- Download Queues
- Smart connection reset
- Hotkey (ctrl+alt+A) to quickly add a download URL from the clipboard

## Demo With Browser Integration

<img align="center" width="850" src="assets/Brisk-Demo.gif">

## Build From Source

Download the Flutter SDK (Recommended version 3.16.9) and set the path variable

```bash
flutter build macos|windows|linux
```

## Features to come

- Dynamic file segmentation for highest download speed
- Download speed limiter
- Download Scheduling

If you have a feature request, please open an issue and explain it in details.

## Credits
- GitHub Actions : [AliML111](https://github.com/AliML111)
- MacOS support : [Norman-w](https://github.com/Norman-w)
