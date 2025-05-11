#!/bin/bash

# Complete OpenSurv Autostart Setup Script
# This script:
# 1. Automatically finds OpenSurv executable
# 2. Sets up OpenSurv to start automatically on boot
# 3. Configures the "mobikom" user to auto-login without password

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

# 1. Find OpenSurv executable using multiple detection methods
echo "Finding OpenSurv executable (this may take a moment)..."
OPENSURV_BIN=""

# Method 1: Check standard locations
for DIR in /usr/bin /usr/local/bin /opt/opensurv /opt/OpenSurv /usr/share/opensurv /home/mobikom /home/mobikom/opensurv; do
    if [ -x "$DIR/opensurv" ]; then
        OPENSURV_BIN="$DIR/opensurv"
        break
    elif [ -x "$DIR/OpenSurv" ]; then
        OPENSURV_BIN="$DIR/OpenSurv"
        break
    fi
done

# Method 2: Check running processes
if [ -z "$OPENSURV_BIN" ]; then
    echo "Checking running processes..."
    # Try lowercase
    PROCESS_PATH=$(ps -ef | grep -i "[o]pensurv" | awk '{print $8}' | head -n 1)
    if [ -n "$PROCESS_PATH" ] && [ -x "$PROCESS_PATH" ]; then
        OPENSURV_BIN="$PROCESS_PATH"
    else
        # Try uppercase
        PROCESS_PATH=$(ps -ef | grep -i "[O]penSurv" | awk '{print $8}' | head -n 1)
        if [ -n "$PROCESS_PATH" ] && [ -x "$PROCESS_PATH" ]; then
            OPENSURV_BIN="$PROCESS_PATH"
        fi
    fi
fi

# Method 3: Use `which` command
if [ -z "$OPENSURV_BIN" ]; then
    echo "Using which command..."
    WHICH_PATH=$(which opensurv 2>/dev/null)
    if [ -n "$WHICH_PATH" ] && [ -x "$WHICH_PATH" ]; then
        OPENSURV_BIN="$WHICH_PATH"
    else
        WHICH_PATH=$(which OpenSurv 2>/dev/null)
        if [ -n "$WHICH_PATH" ] && [ -x "$WHICH_PATH" ]; then
            OPENSURV_BIN="$WHICH_PATH"
        fi
    fi
fi

# Method 4: Quick limited find (faster)
if [ -z "$OPENSURV_BIN" ]; then
    echo "Performing targeted search..."
    for DIR in /usr /opt /home/mobikom; do
        FOUND_PATH=$(find $DIR -name "opensurv" -type f -executable 2>/dev/null | head -n 1)
        if [ -n "$FOUND_PATH" ]; then
            OPENSURV_BIN="$FOUND_PATH"
            break
        fi
        FOUND_PATH=$(find $DIR -name "OpenSurv" -type f -executable 2>/dev/null | head -n 1)
        if [ -n "$FOUND_PATH" ]; then
            OPENSURV_BIN="$FOUND_PATH"
            break
        fi
    done
fi

# Method 5: Check desktop files
if [ -z "$OPENSURV_BIN" ]; then
    echo "Checking desktop files..."
    for DIR in /usr/share/applications /home/mobikom/.local/share/applications; do
        if [ -d "$DIR" ]; then
            DESKTOP_FILE=$(grep -l "opensurv\|OpenSurv" $DIR/*.desktop 2>/dev/null | head -n 1)
            if [ -n "$DESKTOP_FILE" ]; then
                EXEC_LINE=$(grep "^Exec=" "$DESKTOP_FILE" | head -n 1)
                if [ -n "$EXEC_LINE" ]; then
                    # Extract executable from Exec line
                    EXEC_PATH=$(echo "$EXEC_LINE" | sed 's/^Exec=//' | awk '{print $1}')
                    if [ -x "$EXEC_PATH" ]; then
                        OPENSURV_BIN="$EXEC_PATH"
                        break
                    elif [ -x "$(which $EXEC_PATH 2>/dev/null)" ]; then
                        OPENSURV_BIN="$(which $EXEC_PATH)"
                        break
                    fi
                fi
            fi
        fi
    done
fi

# If still not found, look for any binary with 'surv' in the name
if [ -z "$OPENSURV_BIN" ]; then
    echo "Looking for surveillance-related executables..."
    for BINDIR in /usr/bin /usr/local/bin /opt; do
        SURV_BIN=$(find $BINDIR -type f -executable -name "*surv*" 2>/dev/null | head -n 1)
        if [ -n "$SURV_BIN" ]; then
            OPENSURV_BIN="$SURV_BIN"
            break
        fi
    done
fi

if [ -z "$OPENSURV_BIN" ]; then
    echo "Failed to find OpenSurv executable automatically."
    echo "Please run OpenSurv manually once, then run this script again."
    exit 1
fi

echo "Found OpenSurv executable: $OPENSURV_BIN"
OPENSURV_DIR=$(dirname "$OPENSURV_BIN")
echo "OpenSurv directory: $OPENSURV_DIR"

# 2. Create systemd service file for OpenSurv
echo "Creating OpenSurv autostart service..."
cat >/etc/systemd/system/opensurv.service <<EOF
[Unit]
Description=OpenSurv Camera Surveillance System
After=network.target display-manager.service

[Service]
Type=simple
User=mobikom
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/mobikom/.Xauthority
ExecStart=$OPENSURV_BIN
WorkingDirectory=$OPENSURV_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Created OpenSurv service file"

# 3. Set up auto-login for mobikom user
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

# 4. Setup autostart for the mobikom user's desktop environment
echo "Setting up DE-level autostart for mobikom user..."

mkdir -p /home/mobikom/.config/autostart
cat >/home/mobikom/.config/autostart/opensurv.desktop <<EOF
[Desktop Entry]
Type=Application
Name=OpenSurv
Exec=$OPENSURV_BIN
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

chown -R mobikom:mobikom /home/mobikom/.config
chmod +x /home/mobikom/.config/autostart/opensurv.desktop

# 5. Enable and start the OpenSurv service
echo "Enabling OpenSurv service to start on boot..."
systemctl daemon-reload
systemctl enable opensurv.service
systemctl start opensurv.service

# Check if service started successfully
if systemctl is-active opensurv.service >/dev/null 2>&1; then
    echo "✅ OpenSurv service is running!"
else
    echo "⚠️ Note: OpenSurv service may not start until after a graphical session is available."
    echo "The system will still auto-start OpenSurv after reboot."
fi

# Apply changes immediately by restarting display manager
if [ -f /etc/lightdm/lightdm.conf ]; then
    echo "Applying changes by restarting LightDM..."
    systemctl restart lightdm.service
elif [ -f /etc/gdm/custom.conf ] || [ -f /etc/gdm3/custom.conf ]; then
    echo "Applying changes by restarting GDM..."
    if systemctl is-active gdm.service >/dev/null 2>&1; then
        systemctl restart gdm.service
    else
        systemctl restart gdm3.service
    fi
elif [ -f /etc/sddm.conf ] || [ -d /etc/sddm.conf.d ]; then
    echo "Applying changes by restarting SDDM..."
    systemctl restart sddm.service
else
    echo "Display manager not detected."
    echo "Changes will take effect after reboot."
fi

echo ""
echo "Setup complete! Your system is now configured to:"
echo "  1. Automatically login as 'mobikom' user"
echo "  2. Automatically start OpenSurv on boot"
echo ""
echo "If the system hasn't restarted the display manager automatically,"
echo "you can apply changes immediately with: sudo systemctl restart lightdm.service"
echo "Or reboot with: sudo reboot"
