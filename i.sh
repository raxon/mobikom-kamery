#!/bin/bash

# OpenSurv Autostart Setup Script
# This script automatically sets up OpenSurv to start on system boot

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Get the current user (the one who ran sudo)
if [ -n "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER="$(whoami)"
fi

echo "Setting up OpenSurv autostart for user: $CURRENT_USER"

# Find OpenSurv executable
echo "Searching for OpenSurv executable..."
OPENSURV_PATHS=$(find /usr /opt /home/$CURRENT_USER -name "opensurv" -type f -executable 2>/dev/null)

if [ -z "$OPENSURV_PATHS" ]; then
    echo "OpenSurv executable not found. Please enter the path manually:"
    read -p "Path to OpenSurv executable: " OPENSURV_EXEC

    if [ ! -f "$OPENSURV_EXEC" ] || [ ! -x "$OPENSURV_EXEC" ]; then
        echo "Error: The specified file does not exist or is not executable."
        exit 1
    fi
else
    # If multiple paths are found, let the user choose
    PATHS_ARRAY=($OPENSURV_PATHS)

    if [ ${#PATHS_ARRAY[@]} -gt 1 ]; then
        echo "Multiple OpenSurv executables found:"
        for i in "${!PATHS_ARRAY[@]}"; do
            echo "[$i] ${PATHS_ARRAY[$i]}"
        done

        read -p "Select the correct path (number): " SELECTION
        OPENSURV_EXEC="${PATHS_ARRAY[$SELECTION]}"
    else
        OPENSURV_EXEC="$OPENSURV_PATHS"
    fi
fi

echo "Using OpenSurv executable: $OPENSURV_EXEC"

# Get the directory containing the executable
OPENSURV_DIR=$(dirname "$OPENSURV_EXEC")
echo "OpenSurv directory: $OPENSURV_DIR"

# Create systemd service file
cat >/etc/systemd/system/opensurv.service <<EOF
[Unit]
Description=OpenSurv Camera Surveillance System
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
ExecStart=$OPENSURV_EXEC
WorkingDirectory=$OPENSURV_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Created systemd service file: /etc/systemd/system/opensurv.service"

# Reload systemd, enable and start service
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling OpenSurv service to start on boot..."
systemctl enable opensurv.service

echo "Starting OpenSurv service..."
systemctl start opensurv.service

# Check if service started successfully
if systemctl is-active --quiet opensurv.service; then
    echo "✅ OpenSurv service is running!"
else
    echo "⚠️ OpenSurv service failed to start. Check logs with: journalctl -u opensurv.service"
fi

echo ""
echo "Setup complete! OpenSurv will now start automatically on system boot."
echo "Use these commands to manage the service:"
echo "  - Check status: sudo systemctl status opensurv.service"
echo "  - Start service: sudo systemctl start opensurv.service"
echo "  - Stop service: sudo systemctl stop opensurv.service"
echo "  - Disable autostart: sudo systemctl disable opensurv.service"
