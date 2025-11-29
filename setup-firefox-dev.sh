#!/usr/bin/env bash

set -o nounset

NAME=$(basename "$0")
VERSION="v0.9.0"
readonly NAME VERSION

BASE_URL="https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64"
DEFAULT_LANG="en-US"
TARGET_DIR="/opt/firefox-dev"
ARCHIVE_FILE="" # Will be set by download function
SYMLINK_FILE="/usr/local/bin/firefox-dev"
DESKTOP_FILE="/usr/share/applications/Firefox-dev.desktop"
VERSION_FILE="${TARGET_DIR}/.version"
readonly BASE_URL DEFAULT_LANG TARGET_DIR SYMLINK_FILE DESKTOP_FILE VERSION_FILE

USAGE_GLOBAL=$(
    cat <<HELP
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
  status     Check the status of the installation.
  help       Show this help message and exit.
  version    Show this script version and exit.

Source and license:
  https://github.com/saihon/setup-firefox-dev-sh
  This scripts is licensed under the MIT License.
HELP
)

USAGE_INSTALL=$(
    cat <<HELP
Usage: $NAME install [options]

Descriptions:
  Downloads the latest Firefox Developer Edition from Mozilla,
  extracts it to the $TARGET_DIR directory, and creates a
  command-line launcher (symlink) and a desktop application entry.

Options:
  -l, --lang <LANG>  Specify language (e.g., ja, de). Defaults to $DEFAULT_LANG or last used.
  -h, --help         Show install help message and exit.
HELP
)

USAGE_UPDATE=$(
    cat <<HELP
Usage: $NAME update [options]

Descriptions:
  Checks if a newer version of Firefox Developer Edition is available.
  If an update is found, it automatically downloads and installs it,
  replacing the current application files.
  To force an update or reinstall, please use the 'install' command.

Options:
  -c, --check        Check for available updates (does not perform update).
  -l, --lang <LANG>  Specify language (e.g., ja, de). Defaults to $DEFAULT_LANG or last used.
                     Defaults to the installed language.
  -h, --help         Show update help message and exit.
HELP
)

USAGE_UNINSTALL=$(
    cat <<HELP
Usage: $NAME uninstall [options]

Descriptions:
  Removes Firefox Developer Edition, including application files,
  the symbolic link, and the desktop entry.
  This does not remove your browser profiles (e.g., in ~/.mozilla).
HELP
)

USAGE_STATUS=$(
    cat <<HELP
Usage: $NAME status [options]

Descriptions:
  Verifies the installation of Firefox Developer Edition.
  It checks for the existence of necessary files and directories,
  displays current installed version information (from the .version file),
  and validates the symbolic link and desktop entry.
HELP
)
readonly USAGE_GLOBAL USAGE_INSTALL USAGE_UPDATE USAGE_UNINSTALL USAGE_STATUS

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
        tput cnorm # Restore cursor visibility
    fi
}

trap cleanup EXIT

get_latest_version_info() {
    local url_with_lang="$1"
    # Get the final redirected URL's filename without downloading.
    # The filename contains the version string.
    # Returns "LATEST_VERSION|LATEST_FILENAME|LATEST_URL"
    local latest_filename
    local latest_url
    local output
    # Set LC_ALL=C to ensure wget's output (e.g., "Location: ") is not localized,
    # allowing for consistent parsing with grep and sed.
    output=$(LC_ALL=C wget --spider -S "$url_with_lang" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "$output" >&2
        return 1
    fi
    # Get the final redirected URL from the 'Location' header.
    # The sed command does three things:
    # 1. Removes the "Location: " prefix.
    # 2. Removes everything after the first space (to get rid of "[following]").
    # 3. Removes the trailing carriage return character.
    latest_url=$(echo "$output" | grep '^Location: ' | tail -n 1 | sed -e 's/Location: //' -e 's/ .*//' -e 's/\r$//')

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
    local url_to_download="$1"
    local filename="$2"
    local lang="$3"
    printf "Downloading %s (%s) " "$filename" "$lang"
    ARCHIVE_FILE="/tmp/${filename}"

    # Hide cursor for clean animation
    tput civis

    # Spinner animation
    local spin_chars="/-\\|"
    (
        while true; do
            for ((i = 0; i < ${#spin_chars}; i++)); do
                # \r: return to line start, \e[K: clear to end of line
                printf "\r\e[KDownloading %s (%s) [%s]" "$filename" "$lang" "${spin_chars:$i:1}"
                sleep 0.1
            done
        done
    ) &
    local spinner_pid=$!

    # Download from the URL and save it to the specified path.
    if wget -q -O "$ARCHIVE_FILE" "$url_to_download"; then
        # Success
        kill "$spinner_pid" &>/dev/null
        wait "$spinner_pid" 2>/dev/null
        printf "\r\e[KDownloading %s (%s) [\033[32m✔\033[0m]\n" "$filename" "$lang"
    else
        # Failure
        kill "$spinner_pid" &>/dev/null
        wait "$spinner_pid" 2>/dev/null
        printf "\r\e[K\n" # Clear line and add a newline
        output_error_exit "Failed to download from $url_to_download"
    fi
    tput cnorm # Restore cursor
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
        # Returns version|lang
        cat "$VERSION_FILE" | tr -d '\n'
    else
        echo "0|${DEFAULT_LANG}" # Not installed, return version 0 and default lang
    fi
}

save_version_info() {
    local version_to_save="$1"
    local lang_to_save="$2"
    # Ensure parent directory exists
    mkdir -p "$TARGET_DIR"
    echo "${version_to_save}|${lang_to_save}" >"$VERSION_FILE"
}

get_target_lang() {
    # Determine the language to use based on priority:
    # 1. --lang option from command line (OPT_LANG)
    # 2. Language from .version file (installed_lang)
    # 3. Default language (DEFAULT_LANG)
    local installed_lang="$1"

    if [[ -n "$OPT_LANG" ]]; then
        echo "$OPT_LANG"
    elif [[ "$installed_lang" != "$DEFAULT_LANG" && -n "$installed_lang" ]]; then
        echo "$installed_lang"
    else
        echo "$DEFAULT_LANG"
    fi
}

perform_update() {
    local latest_version="$1"
    local latest_filename="$2"
    local latest_url="$3"
    local lang="$4"

    download "$latest_url" "$latest_filename" "$lang"
    printf "Extracting archive: %s\n" "$ARCHIVE_FILE"
    if ! expand_archive_to_target_directory; then output_error_exit "Failed to extract archive"; fi
    save_version_info "$latest_version" "$lang"
}

run_install() {
    local installed_info
    installed_info=$(get_installed_version)
    local _ # installed_version is not used here
    local installed_lang
    IFS='|' read -r _ installed_lang <<<"$installed_info"
    local target_lang
    target_lang=$(get_target_lang "$installed_lang")

    printf "Fetching latest version information...\n"
    latest_info=$(get_latest_version_info "${BASE_URL}&lang=${target_lang}")
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    IFS='|' read -r latest_version latest_filename latest_url <<<"$latest_info"

    perform_update "$latest_version" "$latest_filename" "$latest_url" "$target_lang"

    printf "Creating symbolic link: %s\n" "$SYMLINK_FILE"
    if ! create_symlink; then output_error_exit "Failed to create symbolic link"; fi

    printf "Creating desktop entry: %s\n" "$DESKTOP_FILE"
    if ! create_desktop_file; then output_error_exit "Failed to create desktop entry"; fi

    printf "\nInstallation successful.\n"
    exit 0
}

run_update() {
    local installed_info
    installed_info=$(get_installed_version)
    local installed_version
    local installed_lang
    IFS='|' read -r installed_version installed_lang <<<"$installed_info"

    if [[ "$installed_version" == "0" ]]; then
        output_error_exit "Firefox does not appear to be installed by this script. Please use the 'install' command first."
    fi

    printf "Currently installed version: %s (%s)\n" "$installed_version" "$installed_lang"
    local target_lang=$(get_target_lang "$installed_lang")
    printf "Fetching latest version information...\n"
    latest_info=$(get_latest_version_info "${BASE_URL}&lang=${target_lang}")
    if [[ $? -ne 0 ]]; then
        output_error_exit "Could not get latest version info"
    fi
    IFS='|' read -r latest_version latest_filename latest_url <<<"$latest_info"

    if [[ "$installed_version" == "$latest_version" ]]; then
        printf "You already have the latest version (%s).\n" "$installed_version"
        exit 0
    fi

    printf "New version available: %s\n" "$latest_version"
    perform_update "$latest_version" "$latest_filename" "$latest_url" "$target_lang"
    printf "\nUpdate to version %s successful.\n" "$latest_version"
    exit 0
}

run_update_check() {
    local installed_info
    installed_info=$(get_installed_version)
    local installed_version
    local installed_lang
    IFS='|' read -r installed_version installed_lang <<<"$installed_info"

    if [[ "$installed_version" == "0" ]]; then
        output_error_exit "Firefox does not appear to be installed by this script. Please use the 'install' command first."
    fi

    printf "Currently installed version: %s (%s).\n" "$installed_version" "$installed_lang"

    local target_lang
    target_lang=$(get_target_lang "$installed_lang")

    printf "Fetching latest version information...\n"
    local latest_info
    latest_info=$(get_latest_version_info "${BASE_URL}&lang=${target_lang}")
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

check_target_directory() {
    printf "Target Directory: %s\n" "$TARGET_DIR"
    if [[ -d "$TARGET_DIR" ]]; then
        printf "   ... OK\n"
        return 0
    fi
    printf "   ... Not Found (ERROR)\n"
    return 1
}

check_symlink() {
    printf "Symbolic Link: %s\n" "$SYMLINK_FILE"
    if [[ -L "$SYMLINK_FILE" ]]; then
        local link_target
        link_target=$(readlink "$SYMLINK_FILE")
        if [[ "$link_target" == "${TARGET_DIR}/firefox" ]]; then
            printf "   ... OK (points to %s)\n" "$link_target"
            return 0
        else
            printf "   ... Points to wrong location: %s (ERROR)\n" "$link_target"
            return 1
        fi
    fi
    printf "   ... Not Found (ERROR)\n"
    return 1
}

check_desktop_file() {
    printf "Desktop File: %s\n" "$DESKTOP_FILE"
    if [[ -f "$DESKTOP_FILE" ]]; then
        printf "   ... OK\n"
        return 0
    fi
    printf "   ... Not Found (WARNING)\n"
    return 1
}

show_current_installed_version() {
    local installed_info
    installed_info=$(get_installed_version)
    local installed_version
    local installed_lang
    IFS='|' read -r installed_version installed_lang <<<"$installed_info"

    if [[ "$installed_version" == "0" ]]; then
        echo "Not installed by this script. Please run the 'install' command first."
    else
        printf "Currentry installed version and language: %s (%s)\n" "$installed_version" "$installed_lang"
    fi
}

run_status() {
    printf "Checking Firefox Developer Edition installation status...\n\n"
    show_current_installed_version
    printf "\n"
    local all_ok=true
    if ! check_target_directory; then all_ok=false; fi
    if ! check_symlink; then all_ok=false; fi
    if ! check_desktop_file; then all_ok=false; fi
    printf "\n"
    if "$all_ok"; then
        printf "Installation appears to be OK.\n"
    else
        printf "Found one or more issues.\n"
    fi
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
        PATTERN_SHORT="hl"
        PATTERN_LONG="help|lang"
        ;;
    update)
        USAGE="$USAGE_UPDATE"
        PATTERN_SHORT="chl"
        PATTERN_LONG="check|help|lang"
        ;;
    uninstall)
        USAGE="$USAGE_UNINSTALL"
        PATTERN_SHORT="h"
        PATTERN_LONG="help"
        ;;
    status)
        USAGE="$USAGE_STATUS"
        PATTERN_SHORT="h"
        PATTERN_LONG="help"
        ;;
    esac

    while (($# > 0)); do
        case "$1" in
        -*)
            local is_next_arg=true # Assume value is next arg
            local shift_next=false # Don't shift next arg by default
            local OPTION="$1"
            # Safely get the next argument, or empty string if it doesn't exist.
            local VALUE="${2-}"
            split_by_equals "$OPTION"
            validate_option "$OPTION" "$PATTERN_SHORT" "$PATTERN_LONG"

            # This $ is correctly placed, that is to allow multiple short options (such as -abc) to be specified.
            if [[ "$OPTION" =~ ^(-[[:alnum:]]*h|--help$) ]]; then
                show_help "$USAGE"
            fi

            # Set flag for --lang option (valid for 'install' and 'update')
            if [[ "$OPTION" =~ ^(-[[:alnum:]]*l|--lang$) ]]; then
                validate_required_option "$OPTION" "$VALUE" "$is_next_arg"
                OPT_LANG="$VALUE"
                shift_next=true
            fi

            # Set flag for --check option (only valid for 'update')
            if [[ "$OPTION" =~ ^(-[[:alnum:]]*c|--check$) ]]; then
                OPT_UPDATE_CHECK=true
            fi

            if "$is_next_arg" && "$shift_next"; then shift; fi
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
OPT_LANG=""

case "$SUBCMD" in
install | update | uninstall | status)
    parse_arguments "$@"
    ;;
-v | --version | version)
    show_version
    ;;
-h | --help | help)
    show_help "$USAGE_GLOBAL"
    ;;
*)
    printf "Error: %s is not a subcommand.\n" "$SUBCMD" >&2
    show_help "$USAGE_GLOBAL"
    ;;
esac

readonly OPT_UPDATE_CHECK OPT_LANG

check_dependencies

case "$SUBCMD" in
install)
    ensure_root
    run_install
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
status)
    run_status
    ;;
esac
