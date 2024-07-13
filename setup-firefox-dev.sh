#!/usr/bin/env bash

NAME=$(basename "$0")
VERSION="v0.0.1"
readonly NAME VERSION

URL="https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64&lang=en-US"
TARGET_DIR="/opt/firefox-dev"
ARCHIVE_FILE="/tmp/Firefox-dev.tar.bz2"
SYMLINK_FILE="/usr/local/bin/firefox-dev"
DESKTOP_FILE="/usr/share/applications/Firefox-dev.desktop"
readonly URL TARGET_DIR ARCHIVE_FILE SYMLINK_FILE DESKTOP_FILE

func-output_error_exit() {
    echo "Error: $1." 1>&2
    exit 1
}

func-download() {
    wget -O "$ARCHIVE_FILE" "$URL"
}

func-delete_archive() {
    if [ -f "$ARCHIVE_FILE" ]; then
        rm -f "$ARCHIVE_FILE"
    fi
}

func-expand_archive_to_target_directory() {
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir "$TARGET_DIR"
    fi
    tar xjf "$ARCHIVE_FILE" -C "$TARGET_DIR" --strip-components 1
}

func-delete-target-directory() {
    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
    fi
}

func-create_symlink() {
    func-delete_symlink
    ln -s "${TARGET_DIR}/firefox" "$SYMLINK_FILE"
}

func-delete_symlink() {
    if [ -L "$SYMLINK_FILE" ]; then
        unlink "$SYMLINK_FILE"
    fi
}

func-create_desktop_file() {
    # Reference: https://raw.githubusercontent.com/mozilla/sumo-kb/main/install-firefox-linux/firefox.desktop
    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        echo "Name=Firefox Developer Edition"
        echo "Comment=Browse the World Wide Web"
        echo "Exec=$SYMLINK_FILE"
        echo "GenericName=Web Browser"
        echo "Keywords=Internet;WWW;Browser;Web;Explorer"
        echo "Terminal=false"
        echo "X-MultipleArgs=false"
        echo "Type=Application"
        echo "Icon=$TARGET_DIR/browser/chrome/icons/default/default128.png"
        echo "Categories=GNOME;GTK;Network;WebBrowser;"
        echo "MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;"
        echo "Encoding=UTF-8"
        # StartupNotify=true
    } >>"$DESKTOP_FILE"
}

func-delete_desktop_file() {
    if [ -f "$DESKTOP_FILE" ]; then
        rm -rf "$DESKTOP_FILE"
    fi
}

func-delete_root() {
    if [ "$(id -u)" -ne 0 ]; then
        func-output_error_exit "Please run as root"
    fi
}

case "$1" in
-i | --install | install)
    func-delete_root
    if ! func-download; then func-output_error_exit "Failed to download: $URL"; fi
    if ! func-expand_archive_to_target_directory; then func-output_error_exit "Failed to expand archive: $ARCHIVE_FILE"; fi
    if ! func-create_symlink; then func-output_error_exit "Failed to create symlink: $SYMLINK_FILE"; fi
    if ! func-create_desktop_file; then func-output_error_exit "Failed to create desktop file: $DESKTOP_FILE"; fi
    if ! func-delete_archive; then func-output_error_exit "Failed to delete archive: $ARCHIVE_FILE"; fi
    printf "\nInstallation successful.\n"
    ;;
-u | --update | update)
    func-delete_root
    if ! func-download; then func-output_error_exit "Failed to download: $URL"; fi
    if ! func-expand_archive_to_target_directory; then func-output_error_exit "Failed to expand archive: $ARCHIVE_FILE"; fi
    if ! func-delete_archive; then func-output_error_exit "Failed to delete archive: $ARCHIVE_FILE"; fi
    printf "\nUpdate successful.\n"
    ;;
-U | --uninstall | uninstall)
    func-delete_root
    if ! func-delete-target-directory; then func-output_error_exit "Failed to delete directory: $TARGET_DIR"; fi
    if ! func-delete_symlink; then func-output_error_exit "Failed to delete symlink: $SYMLINK_FILE"; fi
    if ! func-delete_desktop_file; then func-output_error_exit "Failed to delete desktop file: $DESKTOP_FILE"; fi
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
