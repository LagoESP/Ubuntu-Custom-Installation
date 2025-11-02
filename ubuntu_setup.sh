#!/bin/bash
# 
# Ubuntu Setup Utility Script
# ===========================
# This script automates common post-installation tasks.

# --- Initial Sudo Check ---
# Check if the script is being run as root.
if [ "$EUID" -ne 0 ]; then 
    echo "--- Requesting Sudo Privileges ---"
    # Not root, so ask for sudo and validate the password.
    sudo -v
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to obtain sudo privileges. Exiting."
        exit 1
    fi
    # Keep the sudo timestamp alive while the script runs
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
else
    echo "--- Running as Root ---"
    echo "Sudo privileges not required."
fi

clear

echo "=================================================================================="
echo "          🚀 UBUNTU POST-INSTALLATION SETUP UTILITY 🚀"
echo "=================================================================================="
echo "This script will perform administrative setup and optional software installation."
echo ""
read -p "Press [Enter] to continue with setup options..."

# --- Configuration Variables ---
SETUP_USER=${SUDO_USER:-$USER} # SUDO_USER is set when running via sudo
CHROME_DOWNLOAD="/tmp/google-chrome.deb"
GRUB_THEME_REPO="https://github.com/yeyushengfan258/Office-grub-theme"
GRUB_THEME_DIR="/tmp/office-grub-theme"

# The final, verified list for your dock favorites in requested order:
PIN_LIST_FULL="['google-chrome.desktop', 'code_code.desktop', 'postman_postman.desktop', 'org.gnome.Ptyxis.desktop', 'spotify_spotify.desktop', 'discord_discord.desktop', 'steam_steam.desktop', 'org.gnome.Nautilus.desktop', 'snap-store_snap-store.desktop']"

# --- Helper Functions ---

# Function to check if a command exists
command_exists () {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Setup Functions ---

setup_admin_privileges() {
    echo "--- 1. Setting up Admin Privileges for user: ${SETUP_USER} ---"
    
    echo "Adding user '${SETUP_USER}' to 'sudo' (admin) and 'dialout' groups..."
    sudo usermod -aG sudo "${SETUP_USER}"
    sudo usermod -aG dialout "${SETUP_USER}"

    # --- PASSWORDLESS SUDO CONFIGURATION ---
    echo ""
    echo "🚨🚨🚨 WARNING: Enabling Passwordless Sudo 🚨🚨🚨"
    echo "This is a MAJOR SECURITY RISK. User '${SETUP_USER}' will gain full root access"
    echo "without a password prompt. Proceed only if you accept the risk."
    echo "------------------------------------------------------------------"
    
    SUDOERS_FILE="/etc/sudoers.d/90-user-nopasswd"
    echo "${SETUP_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee "${SUDOERS_FILE}" > /dev/null
    sudo chmod 440 "${SUDOERS_FILE}"
    
    echo "✅ Admin privileges and passwordless sudo configured."
}

install_base_tools() {
    echo "--- Installing Base Development Tools (Python3, pip, Git) ---"
    sudo apt update
    
    # Python3, pip, and Git Installation with checks
    command_exists python3 || { echo "Installing python3..."; sudo apt install python3 -y; }
    command_exists pip3 || { echo "Installing pip (python3-pip)..."; sudo apt install python3-pip -y; }
    command_exists git || { echo "Installing git..."; sudo apt install git -y; }

    echo "✅ Base tools checked and installed."
}

install_grub_theme() {
    echo ""
    echo "--- 3. Installing GRUB Theme and Fixing Menu Visibility ---"

    # Pre-install 'dialog' dependency (required by the theme's script)
    echo "Installing 'dialog' dependency..."
    sudo apt install dialog -y

    # 1. Clone the repository
    echo "Cloning theme from GitHub..."
    sudo rm -rf "${GRUB_THEME_DIR}" 
    git clone "${GRUB_THEME_REPO}" "${GRUB_THEME_DIR}"

    # 2. Run the theme's installer
    echo "Running the theme's install.sh script..."
    cd "${GRUB_THEME_DIR}"
    sudo bash install.sh

    # 3. Ensure GRUB menu is visible (This is a must-fix)
    echo "Setting GRUB menu to be visible for 5 seconds..."
    sudo sed -i -E "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" /etc/default/grub
    sudo sed -i -E "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/" /etc/default/grub

    # 4. Update GRUB to apply the theme and timeout
    echo "Updating GRUB to apply theme and settings..."
    sudo update-grub

    # 5. Clean up
    echo "Cleaning up temporary installation files..."
    cd ~
    sudo rm -rf "${GRUB_THEME_DIR}"

    echo "✅ GRUB Theme installed and menu visibility fixed."
}


install_and_customize() {
    echo ""
    echo "--- 2. Installing Additional Software and Customizing GNOME ---"

    echo "Checking for and installing optional software: Chrome, VS Code, Spotify, Discord, Steam, Postman..."
    
    # Chrome Installation (deb) - Check for the binary 'google-chrome'
    if ! command_exists google-chrome; then
        echo "Installing Google Chrome..."
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "${CHROME_DOWNLOAD}"
        sudo dpkg -i "${CHROME_DOWNLOAD}"
        sudo apt --fix-broken install -y
        rm -f "${CHROME_DOWNLOAD}"
    else
        echo "Google Chrome already installed. Skipping."
    fi

    # Snap Installations (Check for the executable provided by the snap)
    command_exists code || { echo "Installing VS Code (snap)..."; sudo snap install code --classic; }
    command_exists spotify || { echo "Installing Spotify (snap)..."; sudo snap install spotify; }
    command_exists discord || { echo "Installing Discord (snap)..."; sudo snap install discord; }
    command_exists steam || { echo "Installing Steam (snap)..."; sudo snap install steam; }
    command_exists postman || { echo "Installing Postman (snap)..."; sudo snap install postman; }
    
    # Remove Firefox (as requested)
    if command_exists firefox; then
        echo "Removing Firefox..."
        sudo apt purge firefox -y
    else
        echo "Firefox not found. Skipping removal."
    fi

    # --- GNOME Customization ---
    echo "Applying GNOME Desktop customizations (Dark Mode, Dock settings, Pinning)..."
    # Run gsettings as the original user, not as root
    sudo -u "${SETUP_USER}" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    sudo -u "${SETUP_USER}" gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    sudo -u "${SETUP_USER}" gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 38
    sudo -u "${SETUP_USER}" gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
    sudo -u "${SETUP_USER}" gsettings set org.gnome.shell favorite-apps "$PIN_LIST_FULL"

    # --- Final Cleanup ---
    echo "Performing final cleanup..."
    sudo apt autoremove -y 
    sudo apt autoclean

    echo "✅ Software installation and desktop customization complete."
}

# --- Main Script Logic ---
clear

echo "=================================================================================="
echo "Please select an option:"
echo "  1  - Admin Setup & Base Tools ONLY (Privileges, Dialout, Passwordless Sudo, Python/Git/Pip)"
echo "  2  - FULL Setup (Option 1 + All Software Install + GNOME Customization + GRUB Theme)"
echo "  0  - Exit without making changes"
echo "=================================================================================="

# Read the option input
read -p "Enter option [1, 2, or 0]: " OPTION

case "$OPTION" in
    1)
        setup_admin_privileges
        install_base_tools
        echo ""
        echo "=================================================================================="
        echo "Option 1 Setup complete. The system will now REBOOT for changes to take effect."
        echo "=================================================================================="
        ;;
    2)
        setup_admin_privileges
        install_base_tools
        install_and_customize
        install_grub_theme # <-- New theme function call here
        echo ""
        echo "=================================================================================="
        echo "Option 2 (FULL) Setup complete. The system will now REBOOT for all changes "
        echo "to the desktop environment and user groups to take effect."
        echo "=================================================================================="
        ;;
    0)
        echo "Exiting setup. No changes made."
        exit 0
        ;;
    *)
        echo "Invalid option selected. Exiting."
        exit 1
        ;;
esac

# --- Mandatory Reboot ---
echo "System will reboot in 10 seconds. Press Ctrl+C to cancel."
sleep 10
sudo reboot
