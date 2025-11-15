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


## Usage

```sh
setup-firefox-dev.sh <subcommand> [options]
```

### Subcommands

#### `help` and `version`
Show help message or this script version information.

```sh
setup-firefox-dev.sh help
setup-firefox-dev.sh version
```

#### `install`
Installs or reinstalls the latest Firefox Developer Edition.

```sh
sudo setup-firefox-dev.sh install
```
**Options:**
*   `-l, --lang <LANG>`: Specify the language for installation (e.g., `ja`, `de`). The chosen language will be remembered for future updates.

**Process:**
1. Downloads the latest `.tar.bz2` archive to the `/tmp` directory.
2. Extracts the archive to `/opt/firefox-dev`.
3. Creates a symbolic link at `/usr/local/bin/firefox-dev`.
4. Creates a desktop entry file at `/usr/share/applications/Firefox-dev.desktop`.
5. Saves the version and language information to `/opt/firefox-dev/.version`.

#### `update`
Checks for a new version and updates if one is found.

```sh
sudo setup-firefox-dev.sh update
```
**Options:**
*   `-c, --check`: Only check for a new version without performing an update. This option does not require sudo.
*   `-l, --lang <LANG>`: Specify a language for the update. The new language will be saved and used for subsequent updates.

**Process:**
1. Compares the currently installed version with the latest version available on the server.
2. If a new version is available, it downloads and extracts it, overwriting the previous installation.

#### `uninstall`
Removes all files and links created by the script. This does not remove your browser profiles.

```sh
sudo setup-firefox-dev.sh uninstall
```
**Process:**
1. Deletes the installation directory: `/opt/firefox-dev`.
2. Deletes the symbolic link: `/usr/local/bin/firefox-dev`.
3. Deletes the desktop entry file: `/usr/share/applications/Firefox-dev.desktop`.


#### status 
Verifies the installation and displays the current status. This command does not require sudo.

```sh
setup-firefox-dev.sh status
```
**Process:**
1. Displays the currently installed version and language. 
2. Checks for the existence of the installation directory (/opt/firefox-dev).
3. Validates the symbolic link (/usr/local/bin/firefox-dev).
4. Checks for the existence of the desktop entry file (/usr/share/applications/Firefox-dev.desktop).

## License

This project is licensed under the MIT License.

<br/>
