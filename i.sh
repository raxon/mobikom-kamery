#!/bin/bash

# Complete OpenSurv Autostart Setup Script
# This script:
# 1. Sets up OpenSurv to start automatically on boot
# 2. Configures the "mobikom" user to auto-login without password

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

echo "Setting up complete OpenSurv autostart configuration..."

# Check if mobikom user exists
if id "mobikom" &>/dev/null; then
    echo "User 'mobikom' exists, will configure auto-login"
else
    echo "User 'mobikom' does not exist. Creating user..."
    useradd -m mobikom
    echo "Set password for 'mobikom' user:"
    passwd mobikom
fi

# 1. Set up autostart for OpenSurv
echo "Creating OpenSurv autostart service..."

# Try to find the OpenSurv executable
echo "Searching for OpenSurv executable..."
OPENSURV_BIN=""

for DIR in /usr/bin /usr/local/bin /opt/opensurv /usr/share/opensurv /home/mobikom; do
    if [ -f "$DIR/opensurv" ]; then
        OPENSURV_BIN="$DIR/opensurv"
        break
    fi
done

if [ -z "$OPENSURV_BIN" ]; then
    echo "Could not find OpenSurv executable, please enter the path:"
    read -p "OpenSurv path: " OPENSURV_BIN

    if [ ! -f "$OPENSURV_BIN" ]; then
        echo "Error: File does not exist. Aborting."
        exit 1
    fi
fi

OPENSURV_DIR=$(dirname "$OPENSURV_BIN")

# Create systemd service file for OpenSurv
cat >/etc/systemd/system/opensurv.service <<EOF
[Unit]
Description=OpenSurv Camera Surveillance System
After=network.target

[Service]
Type=simple
User=mobikom
ExecStart=$OPENSURV_BIN
WorkingDirectory=$OPENSURV_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Created OpenSurv service file"

# 2. Set up auto-login for mobikom user
echo "Setting up auto-login for mobikom user..."

# Check which display manager is in use
if [ -f /etc/lightdm/lightdm.conf ]; then
    # LightDM configuration (Ubuntu, Linux Mint, etc.)
    echo "Configuring LightDM for auto-login..."

    # Backup original config
    cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup

    # Update or create the autologin configuration
    if grep -q "^\[Seat:\*\]" /etc/lightdm/lightdm.conf; then
        # Section exists, update/add values
        sed -i '/^autologin-user=/d' /etc/lightdm/lightdm.conf
        sed -i '/^autologin-user-timeout=/d' /etc/lightdm/lightdm.conf
        sed -i '/^\[Seat:\*\]/a autologin-user=mobikom\nautologin-user-timeout=0' /etc/lightdm/lightdm.conf
    else
        # Create section if it doesn't exist
        echo -e "\n[Seat:*]\nautologin-user=mobikom\nautologin-user-timeout=0" >>/etc/lightdm/lightdm.conf
    fi

elif [ -f /etc/gdm/custom.conf ] || [ -f /etc/gdm3/custom.conf ]; then
    # GDM configuration (GNOME, Debian, etc.)
    echo "Configuring GDM for auto-login..."

    GDM_CONF=""
    if [ -f /etc/gdm/custom.conf ]; then
        GDM_CONF="/etc/gdm/custom.conf"
    else
        GDM_CONF="/etc/gdm3/custom.conf"
    fi

    # Backup original config
    cp $GDM_CONF ${GDM_CONF}.backup

    # Update or create the autologin configuration
    if grep -q "^\[daemon\]" $GDM_CONF; then
        # Section exists, update/add values
        sed -i '/^AutomaticLoginEnable=/d' $GDM_CONF
        sed -i '/^AutomaticLogin=/d' $GDM_CONF
        sed -i '/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=mobikom' $GDM_CONF
    else
        # Create section if it doesn't exist
        echo -e "\n[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=mobikom" >>$GDM_CONF
    fi

elif [ -f /etc/sddm.conf ] || [ -d /etc/sddm.conf.d ]; then
    # SDDM configuration (KDE Plasma, etc.)
    echo "Configuring SDDM for auto-login..."

    if [ -f /etc/sddm.conf ]; then
        # Backup original config
        cp /etc/sddm.conf /etc/sddm.conf.backup

        # Update or create the autologin configuration
        if grep -q "^\[Autologin\]" /etc/sddm.conf; then
            # Section exists, update values
            sed -i '/^User=/d' /etc/sddm.conf
            sed -i '/^Session=/d' /etc/sddm.conf
            sed -i '/^\[Autologin\]/a User=mobikom' /etc/sddm.conf
        else
            # Create section
            echo -e "\n[Autologin]\nUser=mobikom" >>/etc/sddm.conf
        fi
    else
        # Create new config file in conf.d directory
        mkdir -p /etc/sddm.conf.d
        echo -e "[Autologin]\nUser=mobikom" >/etc/sddm.conf.d/autologin.conf
    fi

else
    # Fall back to systemd automatic login
    echo "Could not detect display manager, setting up systemd auto-login..."

    # Create directory if it doesn't exist
    mkdir -p /etc/systemd/system/getty@tty1.service.d/

    # Create override file for getty service
    cat >/etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin mobikom --noclear %I \$TERM
EOF

    echo "Configured systemd for auto-login on tty1"
fi

# 3. Enable and start the OpenSurv service
echo "Enabling OpenSurv service to start on boot..."
systemctl daemon-reload
systemctl enable opensurv.service
systemctl start opensurv.service

# Check if service started successfully
if systemctl is-active opensurv.service >/dev/null 2>&1; then
    echo "✅ OpenSurv service is running!"
else
    echo "⚠️ OpenSurv service failed to start. Check logs with: journalctl -u opensurv.service"
fi

echo ""
echo "Setup complete! Your system is now configured to:"
echo "  1. Automatically login as 'mobikom' user"
echo "  2. Automatically start OpenSurv on boot"
echo ""
echo "These changes will take effect after reboot."
echo "To test, run: sudo reboot"
