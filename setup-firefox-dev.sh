#!/usr/bin/env bash

NAME=$(basename "$0")
VERSION="v0.3.2"
readonly NAME VERSION

URL="https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64&lang=en-US"
TARGET_DIR="/opt/firefox-dev"
ARCHIVE_FILE="" # Will be set by download function
SYMLINK_FILE="/usr/local/bin/firefox-dev"
DESKTOP_FILE="/usr/share/applications/Firefox-dev.desktop"
VERSION_FILE="${TARGET_DIR}/.version"
readonly URL TARGET_DIR SYMLINK_FILE DESKTOP_FILE VERSION_FILE

output_error_exit() {
    echo "Error: $1." 1>&2
    exit 1
}

check_dependencies() {
    local missing_deps=()
    for cmd in wget tar tr grep sed; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    [[ ${#missing_deps[@]} -eq 0 ]] || output_error_exit "Missing required commands: ${missing_deps[*]}"
}

cleanup() {
    if [[ -n "$ARCHIVE_FILE" && -f "$ARCHIVE_FILE" ]]; then
        rm -f "$ARCHIVE_FILE"
    fi
}

trap cleanup EXIT

get_latest_version_info() {
    # Get the final redirected URL's filename without downloading.
    # The filename contains the version string.
    # Returns "LATEST_VERSION|LATEST_FILENAME|LATEST_URL"
    local latest_filename
    local latest_url
    local output
    output=$(wget --spider -S "$URL" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "$output" >&2
        return 1
    fi
    # Get the final redirected URL from the 'Location' header.
    latest_url=$(echo "$output" | grep -oP 'Location: \K.*' | tail -n 1 | tr -d '\r')

    # Extract the filename from the URL using shell parameter expansion,
    # ensuring any query parameters (e.g., ?token=...) are removed first.
    url_no_query=${latest_url%%\?*}
    latest_filename=${url_no_query##*/}

    if [[ -z "$latest_filename" ]]; then
        output_error_exit "Could not determine the latest version filename from the server."
    fi

    # Extract version from filename (e.g., firefox-105.0b9.tar.bz2 -> 105.0b9)
    local latest_version
    latest_version=$(echo "$latest_filename" | sed -n 's/firefox-\(.*\)\.tar\..*/\1/p')

    echo "${latest_version}|${latest_filename}|${latest_url}"
}

download() {
    # Downloads a specific file now
    local filename="$1"
    printf "Downloading %s...\n" "$filename"

    # Set the full path for the archive file.
    ARCHIVE_FILE="/tmp/${filename}"
    # Download from the URL and save it to the specified path.
    if ! wget -O "$ARCHIVE_FILE" "$URL" >/dev/null 2>&1; then
        output_error_exit "Failed to download from $URL"
    fi
}

expand_archive_to_target_directory() {
    mkdir -p "$TARGET_DIR"
    tar xaf "$ARCHIVE_FILE" -C "$TARGET_DIR" --strip-components 1
}

delete_target_directory() {
    # Also remove the version file
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

get_installed_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "0" # Not installed
    fi
}

save_version_info() {
    local version_to_save="$1"
    # Ensure parent directory exists
    mkdir -p "$TARGET_DIR"
    echo "$version_to_save" >"$VERSION_FILE"
}

run_install() {
    printf "Fetching latest version information...\n"
    latest_info=$(get_latest_version_info)
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    IFS='|' read -r latest_version latest_filename latest_url <<<"$latest_info"

    perform_update "$latest_version" "$latest_filename"

    printf "Creating symbolic link: %s\n" "$SYMLINK_FILE"
    if ! create_symlink; then output_error_exit "Failed to create symbolic link"; fi

    printf "Creating desktop entry: %s\n" "$DESKTOP_FILE"
    if ! create_desktop_file; then output_error_exit "Failed to create desktop entry"; fi

    printf "\nInstallation successful.\n"
    exit 0
}

run_update() {
    installed_version=$(get_installed_version)
    if [[ "$installed_version" == "0" ]]; then
        output_error_exit "Could not determine installed version. The app may not have been installed by this script. Use 'install' to re-install, or '--update-force' to overwrite."
    fi

    printf "Currently installed version: %s\n" "$installed_version"
    printf "Fetching latest version information...\n"
    latest_info=$(get_latest_version_info)
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    IFS='|' read -r latest_version latest_filename latest_url <<<"$latest_info"

    if [[ "$installed_version" == "$latest_version" ]]; then
        printf "You already have the latest version (%s).\n" "$installed_version"
        exit 0
    fi

    printf "New version available: %s\n" "$latest_version"
    download "$latest_filename"
    printf "Extracting archive: %s\n" "$ARCHIVE_FILE"
    if ! expand_archive_to_target_directory; then output_error_exit "Failed to extract archive"; fi
    save_version_info "$latest_version"
    printf "\nUpdate to version %s successful.\n" "$latest_version"
    exit 0
}

run_update_force() {
    printf "Forcing update, skipping version check.\n"
    printf "Fetching latest version information...\n"
    latest_info=$(get_latest_version_info)
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    IFS='|' read -r latest_version latest_filename latest_url <<<"$latest_info"

    perform_update "$latest_version" "$latest_filename"
    printf "\nForced update to version %s successful.\n" "$latest_version"
    exit 0
}

run_uninstall() {
    printf "Deleting target directory: %s\n" "$TARGET_DIR"
    if ! delete_target_directory; then output_error_exit "Failed to delete directory"; fi
    printf "Deleting symbolic link: %s\n" "$SYMLINK_FILE"
    if ! delete_symlink; then output_error_exit "Failed to delete symbolic link"; fi
    printf "Deleting desktop entry: %s\n" "$DESKTOP_FILE"
    if ! delete_desktop_file; then output_error_exit "Failed to delete desktop entry"; fi

    printf "\nUninstall successful.\n"
    exit 0
}

show_version_info() {
    echo "$NAME: $VERSION"
    exit 0
}

show_help() {
    printf "\nUsage: %s [options] [arguments]\n" "$NAME"
    printf "\nOptions:\n"
    printf "  -i, --install        Install Firefox developer edition.\n"
    printf "  -u, --update         Update if a new version is available.\n"
    printf "      --update-force   Force update without version check.\n"
    printf "      --uninstall      Uninstall Firefox developer edition.\n"
    printf "  -v, --version        Output version information and exit.\n"
    printf "  -h, --help           Display this help and exit.\n"
    printf "\n"
    exit 0
}

case "$1" in
-i | --install | install)
    check_dependencies
    ensure_root
    run_install
    ;;
-u | --update | update)
    check_dependencies
    ensure_root
    run_update
    ;;
--update-force | update-force)
    check_dependencies
    ensure_root
    run_update_force
    ;;
--uninstall | uninstall)
    check_dependencies
    ensure_root
    run_uninstall
    ;;
-v | --version | version)
    show_version_info
    ;;
*)
    show_help
    ;;
esac
