#!/usr/bin/env bash

set -o nounset

NAME=$(basename "$0")
VERSION="v0.5.0"
readonly NAME VERSION

URL="https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64&lang=en-US"
TARGET_DIR="/opt/firefox-dev"
ARCHIVE_FILE="" # Will be set by download function
SYMLINK_FILE="/usr/local/bin/firefox-dev"
DESKTOP_FILE="/usr/share/applications/Firefox-dev.desktop"
VERSION_FILE="${TARGET_DIR}/.version"
readonly URL TARGET_DIR SYMLINK_FILE DESKTOP_FILE VERSION_FILE

USAGE_GLOBAL=$(cat <<HELP
Usage: $NAME <subcommand> [options]

Descriptions:
  This script provides a simple command-line interface to manage
  the lifecycle of Firefox Developer Edition on Linux systems.
  It automates the process of installing the latest version, checking
  for and applying updates, and performing a clean uninstallation.

Subcommands:
  install    Install Firefox developer edition.
  update     Update if a new version is available.
  uninstall  Uninstall Firefox developer edition.
  help       Show this help message and exit.
  version    Show this script version and exit.

Source and license:
  https://github.com/saihon/setup-firefox-dev-sh
  This scripts is licensed under the MIT License.
HELP
)

USAGE_INSTALL=$(cat <<HELP
Usage: $NAME install [options]

Descriptions:
  Downloads the latest Firefox Developer Edition from Mozilla,
  extracts it to the $TARGET_DIR directory, and creates a
  command-line launcher (symlink) and a desktop application entry.

Options:
  -v, --version  Show current installed version (from the .version file).
  -h, --help     Show install help message and exit.
HELP
)

USAGE_UPDATE=$(cat <<HELP
Usage: $NAME update [options]

Descriptions:
  Checks if a newer version of Firefox Developer Edition is available.
  If an update is found, it automatically downloads and installs it,
  replacing the current application files.
  To force an update or reinstall, please use the 'install' command.

Options:
  -c, --check    Check for available updates (does not perform update).
  -h, --help     Show update help message and exit.
HELP
)

USAGE_UNINSTALL=$(cat <<HELP
Usage: $NAME uninstall [options]

  Removes Firefox Developer Edition, including application files,
  the symbolic link, and the desktop entry.
  This does not remove your browser profiles (e.g., in ~/.mozilla).
HELP
)
readonly USAGE_GLOBAL USAGE_INSTALL USAGE_UPDATE USAGE_UNINSTALL

show_help() {
    printf "\n%s\n\n" "$1"
    exit 0
}

show_version() {
    echo "$NAME: $VERSION"
    exit 0
}

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

perform_update() {
    local latest_version="$1"
    local latest_filename="$2"

    download "$latest_filename"
    printf "Extracting archive: %s\n" "$ARCHIVE_FILE"
    if ! expand_archive_to_target_directory; then output_error_exit "Failed to extract archive"; fi
    save_version_info "$latest_version"
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

show_current_installed_version() {
    installed_version=$(get_installed_version)
    if [[ "$installed_version" == "0" ]]; then
        echo "Firefox Developer Edition is not installed."
    else
        printf "Currently installed version: %s\n" "$installed_version"
    fi
    exit 0
}

run_update() {
    installed_version=$(get_installed_version)
    if [[ "$installed_version" == "0" ]]; then
        output_error_exit "Firefox does not appear to be installed by this script. Please use the 'install' command first."
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
    perform_update "$latest_version" "$latest_filename"
    printf "\nUpdate to version %s successful.\n" "$latest_version"
    exit 0
}

run_update_check() {
    local installed_version
    installed_version=$(get_installed_version)
    if [[ "$installed_version" == "0" ]]; then
        output_error_exit "Firefox does not appear to be installed by this script. Please use the 'install' command first."
    fi

    printf "Currently installed version: %s.\n" "$installed_version"
    printf "Fetching latest version information...\n"
    local latest_info
    latest_info=$(get_latest_version_info)
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    local latest_version
    IFS='|' read -r latest_version _ _ <<<"$latest_info"

    if [[ "$installed_version" == "$latest_version" ]]; then
        printf "You already have the latest version (%s).\n" "$installed_version"
    else
        printf "A new version is available: %s.\n" "$latest_version"
        printf "Run '%s update' to install it.\n" "$NAME"
    fi
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

split_by_equals() {
    # This function modifies variables in the caller's scope:
    # OPTION, VALUE
    IFS='=' read -ra ARRAY <<<"$1"
    OPTION="${ARRAY[0]}"
    if [[ -n "${ARRAY[1]+_}" ]]; then # Check if the second element is set (even if empty)
        VALUE="${ARRAY[1]}"
        is_next_arg=false
    fi
}

validate_option() {
    local opt="$1"
    local pattern_short="$2"
    local pattern_long="$3"

    if [[ "$opt" =~ ^-([^-]+|$) ]] && [[ ! "$opt" =~ ^-[$pattern_short]+$ ]]; then
        output_error_exit "invalid option: '$opt'"
    fi
    if [[ "$opt" =~ ^-- ]] && [[ ! "$opt" =~ ^--($pattern_long)$ ]]; then
        output_error_exit "unrecognized option: '$opt'"
    fi
}

validate_required_option() {
    local opt="$1"
    local val="$2"
    local is_next="$3"

    if [[ -z "$val" ]]; then
        output_error_exit "option '$opt' requires a value"
    fi
    # If the value comes from the next argument, it must not be an option itself.
    if "$is_next" && [[ "$val" =~ ^- ]]; then
        output_error_exit "option '$opt' requires a value"
    fi
}

parse_arguments() {
    local USAGE=""
    local PATTERN_SHORT=""
    local PATTERN_LONG=""

    case "$SUBCMD" in
    install)
        USAGE="$USAGE_INSTALL"
        PATTERN_SHORT="vh"
        PATTERN_LONG="version|help"
        ;;
    update)
        USAGE="$USAGE_UPDATE"
        PATTERN_SHORT="ch"
        PATTERN_LONG="check|help"
        ;;
    uninstall)
        USAGE="$USAGE_UNINSTALL"
        PATTERN_SHORT="h"
        PATTERN_LONG="help"
        ;;
    esac

    while (($# > 0)); do
        case "$1" in
        -*)
            local is_next_arg=true
            local shift_next=false
            local OPTION="$1"
            # Safely get the next argument, or empty string if it doesn't exist.
            local VALUE="${2-}"
            split_by_equals "$OPTION"
            validate_option "$OPTION" "$PATTERN_SHORT" "$PATTERN_LONG"

            if [[ "$OPTION" =~ ^(-[^-]*h|--help)$ ]]; then
                show_help "$USAGE"
            fi

            case "$SUBCMD" in
            install)
                if [[ "$OPTION" =~ ^(-[^-]*v|--version)$ ]]; then
                    OPT_INSTALL_SHOW_VERSION=true
                fi
                ;;
            update)
                if [[ "$OPTION" =~ ^(-[^-]*c|--check)$ ]]; then
                    OPT_UPDATE_CHECK=true
                fi
                ;;
            uninstall)
                # No options for uninstall
                ;;
            esac

            "$shift_next" && shift
            shift
            ;;
        *)
            ((++ARGC))
            ARGS+=("$1")
            shift
            ;;
        esac
    done
}

if (($# == 0)); then
    show_help "$USAGE_GLOBAL"
fi

readonly SUBCMD="$1"
shift

declare -i ARGC=0
declare -a ARGS=()

OPT_UPDATE_CHECK=""
OPT_INSTALL_SHOW_VERSION=""

case "$SUBCMD" in
install | update | uninstall)
    parse_arguments "$@"
    ;;
version)
    show_version
    ;;
help)
    show_help "$USAGE_GLOBAL"
    ;;
*)
    printf "Error: %s is not a subcommand.\n" "$SUBCMD" >&2
    show_help "$USAGE_GLOBAL"
    ;;
esac

readonly OPT_UPDATE_CHECK OPT_INSTALL_SHOW_VERSION

check_dependencies

case "$SUBCMD" in
install)
    if [ -n "$OPT_INSTALL_SHOW_VERSION" ]; then
        show_current_installed_version
    else
        ensure_root
        run_install
    fi
    ;;
update)
    if [ -n "$OPT_UPDATE_CHECK" ]; then
        run_update_check
    else
        ensure_root
        run_update
    fi
    ;;
uninstall)
    ensure_root
    run_uninstall
    ;;
esac
