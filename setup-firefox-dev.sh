#!/usr/bin/env bash

NAME=$(basename "$0")
VERSION="v0.2.0"
readonly NAME VERSION

URL="https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64&lang=en-US"
TARGET_DIR="/opt/firefox-dev"
ARCHIVE_FILE="" # Will be set by mktemp
SYMLINK_FILE="/usr/local/bin/firefox-dev"
DESKTOP_FILE="/usr/share/applications/Firefox-dev.desktop"
readonly URL TARGET_DIR SYMLINK_FILE DESKTOP_FILE

output_error_exit() {
    echo "Error: $1." 1>&2
    exit 1
}

cleanup() {
    if [[ -n "$ARCHIVE_FILE" && -f "$ARCHIVE_FILE" ]]; then
        rm -f "$ARCHIVE_FILE"
    fi
}

trap cleanup EXIT

download() {
    # Use --content-disposition to get the filename from the server.
    # The output of wget (on stderr) is parsed to find the saved filename.
    local output
    output=$(wget -P /tmp --content-disposition "$URL" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "$output" >&2
        return 1
    fi
    ARCHIVE_FILE=$(echo "$output" | grep 'Saving to: ‘' | sed "s/.*Saving to: ‘\([^’]*\)’.*/\1/")
}

expand_archive_to_target_directory() {
    mkdir -p "$TARGET_DIR"
    tar xaf "$ARCHIVE_FILE" -C "$TARGET_DIR" --strip-components 1
}

delete_target_directory() {
    rm -rf "$TARGET_DIR"
}

create_symlink() {
    delete_symlink
    ln -s "${TARGET_DIR}/firefox" "$SYMLINK_FILE"
}

delete_symlink() {
    rm -f "$SYMLINK_FILE"
}

create_desktop_file() {
    # Reference: https://raw.githubusercontent.com/mozilla/sumo-kb/main/install-firefox-linux/firefox.desktop
    cat >"$DESKTOP_FILE" <<-EOF
	[Desktop Entry]
	Version=1.0
	Name=Firefox Developer Edition
	Comment=Browse the World Wide Web
	Exec=$SYMLINK_FILE
	GenericName=Web Browser
	Keywords=Internet;WWW;Browser;Web;Explorer
	Terminal=false
	X-MultipleArgs=false
	Type=Application
	Icon=$TARGET_DIR/browser/chrome/icons/default/default128.png
	Categories=GNOME;GTK;Network;WebBrowser;
	MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
	Encoding=UTF-8
	StartupNotify=true
	EOF
}

delete_desktop_file() {
    rm -f "$DESKTOP_FILE"
}

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        output_error_exit "Please run as root"
    fi
}

do_install_or_update() {
    ensure_root
    printf "Downloading Firefox Developer Edition...\n"
    if ! download; then
        output_error_exit "Failed to download from $URL"
    fi
    printf "Extracting archive: %s\n" "$ARCHIVE_FILE"
    if ! expand_archive_to_target_directory; then
        output_error_exit "Failed to extract archive: $ARCHIVE_FILE"
    fi
}

case "$1" in
-i | --install | install)
    do_install_or_update
    printf "Creating symbolic link: %s\n" "$SYMLINK_FILE"
    if ! create_symlink; then output_error_exit "Failed to create symbolic link"; fi
    printf "Creating desktop entry: %s\n" "$DESKTOP_FILE"
    if ! create_desktop_file; then output_error_exit "Failed to create desktop entry"; fi
    printf "\nInstallation successful.\n"
    ;;
-u | --update | update)
    do_install_or_update
    printf "\nUpdate successful.\n"
    ;;
-U | --uninstall | uninstall)
    ensure_root
    printf "Deleting target directory: %s\n" "$TARGET_DIR"
    if ! delete_target_directory; then output_error_exit "Failed to delete directory"; fi

    printf "Deleting symbolic link: %s\n" "$SYMLINK_FILE"
    if ! delete_symlink; then output_error_exit "Failed to delete symbolic link"; fi

    printf "Deleting desktop entry: %s\n" "$DESKTOP_FILE"
    if ! delete_desktop_file; then output_error_exit "Failed to delete desktop entry"; fi

    printf "\nUninstall successful.\n"
    ;;
-v | --version | version)
    echo "$NAME: $VERSION"
    exit 0
    ;;
*)
    printf "\nUsage: %s [options] [arguments]\n" "$NAME"
    printf "\nOptions:\n"
    printf "  -u, --update     Update Firefox developer edition.\n"
    printf "  -i, --install    Install Firefox developer edition.\n"
    printf "  -U, --uninstall  Uninstall Firefox developer edition.\n"
    printf "  -v, --version    Output version information and exit.\n"
    printf "  -h, --help       Display this help and exit.\n"
    printf "\n"
    exit 0
    ;;
esac
