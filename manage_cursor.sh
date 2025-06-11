#!/bin/bash

# --- Global Variables ---
CURSOR_INSTALL_DIR="/opt/cursor"
APPIMAGE_FILENAME="cursor.AppImage" # Standardized filename
ICON_FILENAME_ON_DISK="cursor-icon.png" # Standardized local icon name

APPIMAGE_PATH="${CURSOR_INSTALL_DIR}/${APPIMAGE_FILENAME}"
ICON_PATH="${CURSOR_INSTALL_DIR}/${ICON_FILENAME_ON_DISK}"
DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"

# --- Download Latest Cursor AppImage Function ---
download_latest_cursor_appimage() {
    API_URL="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
    USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    DOWNLOAD_PATH="/tmp/latest-cursor.AppImage"
    FINAL_URL=$(curl -sL -A "$USER_AGENT" "$API_URL" | jq -r '.url // .downloadUrl')

    if [ -z "$FINAL_URL" ] || [ "$FINAL_URL" = "null" ]; then
        echo "❌ Could not get the final AppImage URL from Cursor API."
        return 1
    fi

    echo "Downloading latest Cursor AppImage from: $FINAL_URL"
    wget -q -O "$DOWNLOAD_PATH" "$FINAL_URL"

    if [ $? -eq 0 ] && [ -s "$DOWNLOAD_PATH" ]; then
        echo "✅ Downloaded latest Cursor AppImage successfully!"
        echo "$DOWNLOAD_PATH"
        return 0
    else
        echo "❌ Failed to download the AppImage."
        return 1
    fi
}

# --- Installation Function ---
installCursor() {
    # Check if the AppImage already exists using the global path
    if ! [ -f "$APPIMAGE_PATH" ]; then
        echo "Installing Cursor AI IDE on Ubuntu..."
        echo "How do you want to provide the Cursor AppImage?"
        echo "1. Auto-download the latest AppImage from Cursor website (recommended)"
        echo "2. Specify local file path manually"
        read -p "Choose 1 or 2: " appimage_option

        if [ "$appimage_option" = "1" ]; then
            # --- Dependency Checks ---
            if ! command -v curl &> /dev/null; then
                echo "curl is not installed. Installing..."
                sudo apt-get update
                sudo apt-get install -y curl
            fi
            # --- End Dependency Checks ---

            echo "⏳ Downloading the latest Cursor AppImage, please wait..."
            CURSOR_DOWNLOAD_PATH=$(download_latest_cursor_appimage | tail -n 1)
            if [ $? -ne 0 ] || [ ! -f "$CURSOR_DOWNLOAD_PATH" ]; then
                echo "==============================="
                echo "❌ Auto-download failed!"
                echo "==============================="
                echo "Would you like to specify the local file path manually instead? (y/n)"
                read -r retry_option
                if [[ "$retry_option" =~ ^[Yy]$ ]]; then
                    read -p "Enter Cursor AppImage download path in your laptop/PC: " CURSOR_DOWNLOAD_PATH
                else
                    echo "Exiting installation."
                    exit 1
                fi
            fi
        else
            read -p "Enter Cursor AppImage download path in your laptop/PC: " CURSOR_DOWNLOAD_PATH
        fi

        # Get the path of the script directory
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        LOCAL_ICON_PATH="${SCRIPT_DIR}/cursor-icon.png"
        if [ ! -f "$LOCAL_ICON_PATH" ]; then
            echo "❌ Icon file not found at ${LOCAL_ICON_PATH}. Please ensure the icon file is in the same directory as this script."
            exit 1
        fi
        echo "Using icon file: ${LOCAL_ICON_PATH}"

        echo "Creating installation directory ${CURSOR_INSTALL_DIR}..."
        sudo mkdir -p "$CURSOR_INSTALL_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to create installation directory. Please check permissions."
            exit 1
        fi
        echo "Installation directory ${CURSOR_INSTALL_DIR} created successfully."

        echo "Move Cursor AppImage to $APPIMAGE_PATH..."
        sudo mv "$CURSOR_DOWNLOAD_PATH" "$APPIMAGE_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to move AppImage. Please check the URL and permissions."
            exit 1
        fi
        echo "Cursor AppImage moved successfully."

        echo "Making AppImage executable..."
        sudo chmod +x "$APPIMAGE_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to make AppImage executable. Please check permissions."
            exit 1
        fi
        echo "AppImage is now executable."

        echo "Copying icon file to $ICON_PATH..."
        sudo cp "$LOCAL_ICON_PATH" "$ICON_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to copy icon file. Please check permissions."
            exit 1
        fi
        echo "Icon file copied successfully."

        echo "Creating .desktop entry for Cursor..."
        sudo bash -c "cat > \"$DESKTOP_ENTRY_PATH\"" <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=$APPIMAGE_PATH --no-sandbox
Icon=$ICON_PATH
Type=Application
Categories=Development;
EOL

        echo "✅ Cursor AI IDE installation complete. You can find it in your application menu."
    else
        echo "ℹ️ Cursor AI IDE seems to be already installed at $APPIMAGE_PATH."
        echo "If you want to update, please choose the update option."
    fi
}

# --- Update Function ---
updateCursor() {
    # Uses global APPIMAGE_PATH
    if [ -f "$APPIMAGE_PATH" ]; then
        echo "Updating Cursor AI IDE..."
        echo "How do you want to provide the new Cursor AppImage?"
        echo "1. Auto-download the latest AppImage from Cursor website (recommended)"
        echo "2. Specify local file path manually"
        read -p "Choose 1 or 2: " appimage_option

        if [ "$appimage_option" = "1" ]; then
            echo "⏳ Downloading the latest Cursor AppImage, please wait..."
            CURSOR_DOWNLOAD_PATH=$(download_latest_cursor_appimage | tail -n 1)
            if [ $? -ne 0 ] || [ ! -f "$CURSOR_DOWNLOAD_PATH" ]; then
                echo "==============================="
                echo "❌ Auto-download failed!"
                echo "==============================="
                echo "Would you like to specify the local file path manually instead? (y/n)"
                read -r retry_option
                if [[ "$retry_option" =~ ^[Yy]$ ]]; then
                    read -p "Enter new Cursor AppImage download path in your laptop/PC: " CURSOR_DOWNLOAD_PATH
                else
                    echo "Exiting update."
                    exit 1
                fi
            fi
        else
            read -p "Enter new Cursor AppImage download path in your laptop/PC: " CURSOR_DOWNLOAD_PATH
        fi

        echo "Removing old Cursor AppImage at $APPIMAGE_PATH..."
        sudo rm -f "$APPIMAGE_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to remove old AppImage. Please check permissions."
            exit 1
        fi
        echo "Old AppImage removed successfully."

        echo "Move new Cursor AppImage in $CURSOR_DOWNLOAD_PATH to $APPIMAGE_PATH..."
        sudo mv "$CURSOR_DOWNLOAD_PATH" "$APPIMAGE_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to move new AppImage. Please check the URL and permissions."
            exit 1
        fi
        echo "New AppImage moved successfully."

        echo "Making new AppImage executable..."
        sudo chmod +x "$APPIMAGE_PATH"
        if [ $? -ne 0 ]; then
            echo "❌ Failed to make new AppImage executable. Please check permissions."
            exit 1
        fi
        echo "New AppImage is now executable."

        echo "✅ Cursor AI IDE update complete. Please restart Cursor if it was running."
    else
        echo "❌ Cursor AI IDE is not installed at $APPIMAGE_PATH. Please choose the install option first."
        exec "$0"
    fi
}

# --- Uninstall Function ---
uninstallCursor() {
    if [ -f "$APPIMAGE_PATH" ] || [ -f "$DESKTOP_ENTRY_PATH" ] || [ -f "$ICON_PATH" ]; then
        echo "Uninstalling Cursor AI IDE..."
        
        # Remove AppImage
        if [ -f "$APPIMAGE_PATH" ]; then
            echo "Removing Cursor AppImage..."
            sudo rm -f "$APPIMAGE_PATH"
            if [ $? -ne 0 ]; then
                echo "❌ Failed to remove AppImage. Please check permissions."
                exit 1
            fi
            echo "✅ AppImage removed successfully."
        fi

        # Remove Icon
        if [ -f "$ICON_PATH" ]; then
            echo "Removing Cursor icon..."
            sudo rm -f "$ICON_PATH"
            if [ $? -ne 0 ]; then
                echo "❌ Failed to remove icon. Please check permissions."
                exit 1
            fi
            echo "✅ Icon removed successfully."
        fi

        # Remove Desktop Entry
        if [ -f "$DESKTOP_ENTRY_PATH" ]; then
            echo "Removing desktop entry..."
            sudo rm -f "$DESKTOP_ENTRY_PATH"
            if [ $? -ne 0 ]; then
                echo "❌ Failed to remove desktop entry. Please check permissions."
                exit 1
            fi
            echo "✅ Desktop entry removed successfully."
        fi

        # Remove installation directory if empty
        if [ -d "$CURSOR_INSTALL_DIR" ]; then
            sudo rmdir --ignore-fail-on-non-empty "$CURSOR_INSTALL_DIR"
        fi

        echo "✅ Cursor AI IDE has been successfully uninstalled."
    else
        echo "❌ Cursor AI IDE is not installed or was already uninstalled."
    fi
}

# --- Main Menu ---
echo "Cursor AI IDE Management"
echo "------------------------"
echo "1. Install Cursor"
echo "2. Update Cursor"
echo "3. Uninstall Cursor"
echo "------------------------"

read -p "Please choose an option (1, 2 or 3): " choice

case $choice in
    1)
        installCursor
        ;;
    2)
        updateCursor
        ;;
    3)
        uninstallCursor
        ;;
    *)
        echo "❌ Invalid option. Exiting."
        exit 1
        ;;
esac

exit 0
