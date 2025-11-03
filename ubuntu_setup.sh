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
echo "         🚀 UBUNTU POST-INSTALLATION SETUP UTILITY 🚀"
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
# 1. Chrome, 2. VSCode, 3. Postman, 4. Terminal, 5. Spotify, 6. Discord, 7. Steam, 8. Files, 9. Appstore
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
    
    # Python3, pip, venv, and Git Installation with checks
    command_exists python3 || { echo "Installing python3..."; sudo apt install python3 -y; }
    command_exists pip3 || { echo "Installing pip (python3-pip)..."; sudo apt install python3-pip -y; }
    echo "Checking/Installing venv (python3-venv)..."
    sudo apt install python3-venv -y
    command_exists git || { echo "Installing git..."; sudo apt install git -y; }

    echo "✅ Base tools checked and installed."
}

install_grub_theme() {
    echo ""
    echo "--- 3. Installing GRUB Theme ---"

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

    # 3. Clean up
    echo "Cleaning up temporary installation files..."
    cd ~
    sudo rm -rf "${GRUB_THEME_DIR}"

    echo "✅ GRUB Theme installed."
}

configure_grub_boot_order() {
    echo ""
    echo "--- 4. Configuring GRUB Boot Order (Windows First) ---"

    # --- PASO 1: REPARAR GRUB (Por si acaso) ---
    echo "Purging grub-customizer and reinstalling GRUB packages..."
    sudo apt purge grub-customizer -y
    sudo apt install --reinstall grub-common grub-pc-bin grub2-common

    # --- PASO 2: CREAR LA ENTRADA "Windows" (Renombrar y Reordenar) ---
    echo "Creating custom 'Windows' entry..."

    # 2a. Encontrar la partición EFI de Windows y su UUID
    EFI_PARTITION=$(sudo blkid -L "SYSTEM" || sudo blkid -L "ESP" || sudo fdisk -l | grep -i "EFI System" | cut -d' ' -f1)
    EFI_UUID=$(sudo blkid -s UUID -o value "${EFI_PARTITION}")

    if [ -z "${EFI_UUID}" ]; then
        echo "❌ WARNING: No Windows EFI partition found."
        echo "  Skipping Windows boot order customization."
        # Run update-grub anyway to apply theme
        sudo update-grub
        return
    else
        echo "✅ Windows EFI partition found (${EFI_PARTITION}) with UUID: ${EFI_UUID}"
        
        # 2b. Crear la entrada personalizada para 'Windows' al principio de la lista
        # Usamos 08_custom_windows para que se ejecute antes que 10_linux (Ubuntu)
        sudo tee /etc/grub.d/08_custom_windows > /dev/null <<EOF
#!/bin/sh
echo "Found Windows (Custom Entry)" >&2
cat << 'EOM'
menuentry 'Windows' --class windows --class os {
    insmod part_gpt
    insmod fat
    insmod chain
    search --fs-uuid --no-floppy --set=root ${EFI_UUID}
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
EOM
EOF
        
        # 2c. Hacer ejecutable el nuevo script
        sudo chmod +x /etc/grub.d/08_custom_windows
        
        # 2d. Desactivar el 'os-prober' original para evitar duplicados
        sudo chmod -x /etc/grub.d/30_os-prober 2>/dev/null
        echo "Custom 'Windows' entry created and os-prober disabled."
    fi

    # --- PASO 3: LIMPIAR ENTRADAS EXTRA ---
    echo "Disabling extra GRUB menu entries..."
    sudo chmod -x /etc/grub.d/10_linux_zfs 2>/dev/null
    sudo chmod -x /etc/grub.d/20_linux_xen 2>/dev/null
    sudo chmod -x /etc/grub.d/20_memtest86+ 2>/dev/null
    sudo chmod -x /etc/grub.d/30_uefi-firmware 2>/dev/null
    sudo chmod -x /etc/grub.d/35_fwupd 2>/dev/null

    # --- PASO 4: CONFIGURAR EL ARCHIVO GRUB ---
    echo "Configuring /etc/default/grub..."

    # 4a. Ocultar "Advanced options for Ubuntu"
    if grep -q "GRUB_DISABLE_SUBMENU" /etc/default/grub; then
        sudo sed -i -E "s/^GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/" /etc/default/grub
    else
        echo 'GRUB_DISABLE_SUBMENU=y' | sudo tee -a /etc/default/grub
    fi

    # 4b. Establecer el arranque por defecto en '0' (que ahora será 'Windows')
    sudo sed -i -E "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/" /etc/default/grub

    # 4c. Desactivar 'SAVEDEFAULT'
    sudo sed -i '/^GRUB_SAVEDEFAULT=.*/d' /etc/default/grub
    echo 'GRUB_SAVEDEFAULT=false' | sudo tee -a /etc/default/grub

    # 4d. Asegurarse de que el menú sea visible
    sudo sed -i -E "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" /etc/default/grub
    sudo sed -i -E "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/" /etc/default/grub

    # --- PASO 5: APLICAR TODO ---
    echo "Applying all GRUB changes..."
    sudo update-grub
    echo "✅ GRUB reconfigured. Windows is now the default."
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

    # --- GNOME Customization (FIXED) ---
    echo "Applying GNOME Desktop customizations (Dark Mode, Dock settings, Pinning)..."
    
    # We must explicitly set the D-Bus address for gsettings to work from a sudo script.
    export DBUS_PATH="unix:path=/run/user/$(id -u ${SETUP_USER})/bus"
    
    # Run gsettings as the original user, using the correct D-Bus path and schema
    sudo -u "${SETUP_USER}" DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    sudo -u "${SETUP_USER}" DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    sudo -u "${SETUP_USER}" DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 34
    sudo -u "${SETUP_USER}" DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
    sudo -u "${SETUP_USER}" DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.shell favorite-apps "$PIN_LIST_FULL"

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
echo "  2  - FULL Setup (Option 1 + All Software Install + GNOME/GRUB Customization)"
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
        install_grub_theme
        configure_grub_boot_order
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
