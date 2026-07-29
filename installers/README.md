<!-- markdownlint-disable MD013 -->

# Money Pod Installers

Flutter supports multiple platform targets. Flutter based apps can run
native on Android, iOS, Linux, MacOS, and Windows, as well as directly
in a browser from the web. Flutter functionality is essentially
identical across all platforms so the experience across different
platforms will be very similar.

Visit the
[CHANGELOG](https://github.com/gjwgit/moneypod/blob/dev/CHANGELOG.md)
for the latest updates.

Run the app online: [**web**](https://moneypod.solidcommunity.au).

Download the latest version:

+ **Android**
  [aab](https://solidcommunity.au/installers/moneypod.aab) or
  [apk](https://solidcommunity.au/installers/moneypod.apk);
+ **GNU/Linux**
  [deb](https://solidcommunity.au/installers/moneypod_amd64.deb) or
  [snap](https://solidcommunity.au/installers/moneypod_amd64.snap) or
  [zip](https://solidcommunity.au/installers/moneypod-linux.zip);
+ **macOS**
  [dmg](https://solidcommunity.au/installers/moneypod-macos.dmg) or
  [zip](https://solidcommunity.au/installers/moneypod-macos.zip);
+ **Windows**
  [exe](https://solidcommunity.au/installers/moneypod-windows-inno.exe) or
  [zip](https://solidcommunity.au/installers/moneypod-windows.zip).

## Prerequisite

There are no specific prerequisites for installing and running the
app.

## Android

You can side load the latest version of the app by downloading the
[installer](https://solidcommunity.au/installers/moneypod.apk)
through your Android device's browser. This will download the app to
your Android device. Then visit the Downloads folder (choosing the
menu option in the browser) where you can click on the
`moneypod.apk` file. Your browser will ask if you would like to
installing the app locally.

## Linux

### Deb Install for Debian/Ubuntu

Download
[moneypod_amd64.deb](https://solidcommunity.au/installers/moneypod_amd64.deb)
and install:

```bash
wget https://solidcommunity.au/installers/moneypod_amd64.deb -O moneypod_amd64.deb
sudo dpkg --install moneypod_amd64.deb
```

### Linux Snap Install

Download
[moneypod_amd64.snap](https://solidcommunity.au/installers/moneypod_amd64.snap)
and install:

```bash
wget https://solidcommunity.au/installers/moneypod_amd64.snap -O moneypod_amd64.snap
sudo snap install --dangerous moneypod_amd64.snap
```

### Linux Zip Install

Download
[moneypod-linux.zip](https://solidcommunity.au/installers/moneypod-linux.zip)

To try it out:

```bash
wget https://solidcommunity.au/installers/moneypod-linux.zip -O moneypod-linux.zip
unzip moneypod-linux.zip -d moneypod
./moneypod/moneypod
```

To install for the local user and to make it known to GNOME and KDE
with a desktop icon for their desktop (which is automatically done
using the deb or snap installations), begin by downloading the **zip**
and installing that into a local folder:

```bash
unzip moneypod-linux.zip -d ${HOME}/.local/share/moneypod
```

Then set up your local installation (only required once):

```bash
ln -s ${HOME}/.local/share/moneypod/moneypod ${HOME}/.local/bin/
wget https://raw.githubusercontent.com/gjwgit/moneypod/dev/installers/app.desktop -O ${HOME}/.local/share/applications/moneypod.desktop
sed -i "s/USER/$(whoami)/g" ${HOME}/.local/share/applications/moneypod.desktop
mkdir -p ${HOME}/.local/share/icons/hicolor/256x256/apps/
wget https://github.com/gjwgit/moneypod/raw/dev/installers/app.png -O ${HOME}/.local/share/icons/hicolor/256x256/apps/moneypod.png
```

To install for any user on the computer:

```bash
sudo unzip moneypod-linux.zip -d /opt/moneypod
sudo ln -s /opt/moneypod/moneypod /usr/local/bin/
wget https://raw.githubusercontent.com/gjwgit/moneypod/dev/installers/app.desktop -O ${HOME}/usr/local/share/applications/moneypod.desktop
wget https://github.com/gjwgit/moneypod/raw/dev/installers/app.png -O ${HOME}/use/local/share/icons/moneypod.png
```

Once installed you can run the app from the GNOME desktop through
Alt-F2 and type `moneypod` then Enter.

## macOS

### macOS Zip Install

Download
[moneypod-macos.zip](https://solidcommunity.au/installers/moneypod-macos.zip).

Open the downloaded file on your Mac. Then, holding the Control key
click on the app icon to display a menu. Choose `Open`. Then accept
the warning (or give permission to install the app) to then run the
app. The app should run without the warning next time.

## Web -- No Installation Required

No installer is required for a browser based experience of
Moneypod. Simply visit
[https://moneypod.solidcommunity.au](https://moneypod.solidcommunity.au).

Also, your Web browser will provide an option in its menus to install
the app locally, which can add an icon to your home screen to start
the web-based app directly.

## Windows

### Windows Self Extracting Archive

Download and run the self extracting archive
[moneypod-windows-inno.exe](https://solidcommunity.au/installers/moneypod-windows-inno.exe)
to self install the app on Windows.
