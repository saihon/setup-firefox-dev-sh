# setup-firefox-dev-sh

Script to install, update, and uninstall Firefox Developer Edition for Linux.

<br/>

# Download

Download `.sh` file.
```sh
wget https://raw.githubusercontent.com/saihon/setup-firefox-dev-sh/main/setup-firefox-dev.sh
```

Change file mode.

```sh
chmod 755 setup-firefox-dev.sh
```

<br/>


# Usage

Installation.

```sh
sudo setup-firefox-dev.sh install
```

1. Download archive `.tar.gz2` to `/tmp` directory.
2. Expand it to `/opt/firefox-dev` directory.
3. Create symbolic link to `/usr/local/bin/firefox-dev`.
4. Create `/usr/share/applications/Firefox-dev.desktop` file.

Update.

```sh
sudo setup-firefox-dev.sh update
```

1. Download archive file (e.g., `.tar.bz2`, `.tar.xz`) to `/tmp` directory.
2. Expand it to `/opt/firefox-dev` directory.


Uninstall.

```sh
sudo setup-firefox-dev.sh uninstall
```

1. Delete symbolic link `/usr/local/bin/firefox-dev`.
2. Delete `/opt/firefox-dev` directory.
3. Delete `/usr/share/applications/Firefox-dev.desktop` file.

<br/>
