# setup-firefox-dev-sh

A script to easily install, update, and uninstall Firefox Developer Edition on Linux.

<br/>

## Download and Setup

Download `.sh` file.
```sh
wget https://raw.githubusercontent.com/saihon/setup-firefox-dev-sh/main/setup-firefox-dev.sh
```

Change file mode.

```sh
chmod 755 setup-firefox-dev.sh
```

Move to a directory in your PATH (e.g., /usr/local/bin/).

```sh
sudo mv setup-firefox-dev.sh /usr/local/bin/
```

<br/>


# Usage

|Command|Alias(es)|Description|
|:------|:--------|:----------|
|install|-i,--install|Install Firefox Developer Edition.|
|update|-u,--update|Update if a new version is available.|
|update-force|--update-force|Force update without version check.|
|uninstall|-U,--uninstall|Uninstall Firefox Developer Edition.|
|version|-v,--version|Show the script version.|
|help|-h,--help|Display the help message.|


## Install

Installs the latest Firefox Developer Edition.

```sh
sudo setup-firefox-dev.sh install
```

1. Download the latest `.tar.gz2` archive to `/tmp` directory.
2. Extracts the archive to `/opt/firefox-dev`.
3. Creates a symbolic link at `/usr/local/bin/firefox-dev`.
4. Creates a desktop entry file at `/usr/share/applications/Firefox-dev.desktop`.
5. Saves the version information to `/opt/firefox-dev/.version`.

## Update

Checks for a new version and updates if one is found.

```sh
sudo setup-firefox-dev.sh update
```

1. Compares the currently iinstalled version with the latest version available on the server.
2. If a new version is available, it downloads and extracts it, overwriting the previous installation.


## Uninstall

Removes all files and links created by the script.

```sh
sudo setup-firefox-dev.sh uninstall
```

1. Deletes the installation directory: `/opt/firefox-dev`.
2. Deletes the symbolic link: `/usr/local/bin/firefox-dev`.
3. Deletes the desktop entry file: `/usr/share/applications/Firefox-dev.desktop`.

<br/>
