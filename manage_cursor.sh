#!/bin/bash

# --- Global Variables ---
CURSOR_INSTALL_DIR="/opt/cursor"
APPIMAGE_FILENAME="cursor.AppImage"
ICON_FILENAME_ON_DISK="cursor-icon.png"

APPIMAGE_PATH="${CURSOR_INSTALL_DIR}/${APPIMAGE_FILENAME}"
ICON_PATH="${CURSOR_INSTALL_DIR}/${ICON_FILENAME_ON_DISK}"
DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"

# Get the path of the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_ICON_PATH="${SCRIPT_DIR}/cursor-icon.png"

# --- Helper Functions ---
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    if ! command -v wget &> /dev/null; then
        missing_deps+=("wget")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Installing required dependencies: ${missing_deps[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
    fi
}

handle_error() {
    local error_message="$1"
    echo "❌ Error: $error_message"
    exit 1
}

create_desktop_entry() {
    echo "Creating .desktop entry for Cursor..."
    sudo bash -c "cat > \"$DESKTOP_ENTRY_PATH\"" <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=$APPIMAGE_PATH --no-sandbox
Icon=$ICON_PATH
Type=Application
Categories=Development;
EOL
}

# --- File Operations ---
check_file_exists() {
    local file_path="$1"
    local error_message="$2"
    if [ ! -f "$file_path" ]; then
        handle_error "$error_message"
    fi
}

remove_file_if_exists() {
    local file_path="$1"
    [ -f "$file_path" ] && sudo rm -f "$file_path"
}

make_executable() {
    local file_path="$1"
    sudo chmod +x "$file_path" || handle_error "Failed to make $file_path executable."
}

# --- AppImage Management ---
get_appimage_path() {
    echo "⏳ Downloading latest Cursor AppImage..." >&2
    check_dependencies
    local download_path=$(download_latest_cursor_appimage)
    echo "$download_path"
}

download_latest_cursor_appimage() {
    local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
    local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    local download_path="/tmp/latest-cursor.AppImage"
    
    echo "⏳ Fetching download URL from Cursor API..." >&2
    local final_url=$(curl -sL -A "$user_agent" "$api_url" | jq -r '.url // .downloadUrl')

    if [ -z "$final_url" ] || [ "$final_url" = "null" ]; then
        handle_error "Could not get the final AppImage URL from Cursor API."
    fi

    echo "Downloading latest Cursor AppImage from: $final_url" >&2
    wget -q -O "$download_path" "$final_url" || handle_error "Failed to download the AppImage."

    if [ -s "$download_path" ]; then
        echo "✅ Downloaded latest Cursor AppImage successfully!" >&2
        echo "$download_path"
        return 0
    else
        handle_error "Downloaded AppImage is empty."
    fi
}

# --- Main Functions ---
installCursor() {
    echo "Installing Cursor AI IDE..."
    
    # Check if already installed
    if [ -f "$APPIMAGE_PATH" ]; then
        handle_error "Cursor AI IDE is already installed at $APPIMAGE_PATH. Please uninstall first if you want to reinstall."
    fi

    # Verify icon exists
    check_file_exists "$LOCAL_ICON_PATH" "Icon file not found at ${LOCAL_ICON_PATH}. Please ensure the icon file is in the same directory as this script."
    echo "Using icon file: ${LOCAL_ICON_PATH}"

    # Get AppImage
    local cursor_download_path=$(get_appimage_path)

    # Create installation directory
    echo "Creating installation directory ${CURSOR_INSTALL_DIR}..."
    sudo mkdir -p "$CURSOR_INSTALL_DIR" || handle_error "Failed to create installation directory."

    # Move AppImage
    echo "Installing Cursor AppImage to $APPIMAGE_PATH..."
    sudo mv "$cursor_download_path" "$APPIMAGE_PATH" || handle_error "Failed to move AppImage."
    make_executable "$APPIMAGE_PATH"

    # Copy icon
    echo "Copying icon file to $ICON_PATH..."
    sudo cp "$LOCAL_ICON_PATH" "$ICON_PATH" || handle_error "Failed to copy icon file."

    # Create desktop entry
    create_desktop_entry

    echo "✅ Cursor AI IDE installation complete. You can find it in your application menu."
}

uninstallCursor() {
    local files_exist=false
    
    if [ -f "$APPIMAGE_PATH" ] || [ -f "$DESKTOP_ENTRY_PATH" ] || [ -f "$ICON_PATH" ]; then
        files_exist=true
    else
        echo "❌ Cursor AI IDE is not installed or was already uninstalled."
        return 0
    fi

    echo "Uninstalling Cursor AI IDE..."
    
    # Remove files
    remove_file_if_exists "$APPIMAGE_PATH"
    remove_file_if_exists "$ICON_PATH"
    remove_file_if_exists "$DESKTOP_ENTRY_PATH"
    
    # Remove installation directory if empty
    [ -d "$CURSOR_INSTALL_DIR" ] && sudo rmdir --ignore-fail-on-non-empty "$CURSOR_INSTALL_DIR"

    if [ "$files_exist" = true ]; then
        echo "✅ Cursor AI IDE has been successfully uninstalled."
    fi
}

# --- Main Menu ---
show_menu() {
    echo "Cursor AI IDE Management"
    echo "------------------------"
    echo "1. Install Cursor (Latest Version)"
    echo "2. Uninstall Cursor"
    echo "------------------------"

    read -p "Please choose an option (1 or 2): " choice

    case $choice in
        1) installCursor ;;
        2) uninstallCursor ;;
        *) handle_error "Invalid option." ;;
    esac
}

# --- Main Execution ---
show_menu
exit 0
