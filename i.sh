#!/bin/bash

# OpenSurv Autostart Setup Script for Debian
# This script sets up OpenSurv to start on system boot

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
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
OPENSURV_EXEC=""

# Try common locations
if [ -x "/usr/bin/opensurv" ]; then
    OPENSURV_EXEC="/usr/bin/opensurv"
elif [ -x "/usr/local/bin/opensurv" ]; then
    OPENSURV_EXEC="/usr/local/bin/opensurv"
elif [ -x "/opt/opensurv/opensurv" ]; then
    OPENSURV_EXEC="/opt/opensurv/opensurv"
fi

# If not found, ask user
if [ -z "$OPENSURV_EXEC" ]; then
    echo "OpenSurv executable not found. Please enter the path manually:"
    read -p "Path to OpenSurv executable: " OPENSURV_EXEC

    if [ ! -f "$OPENSURV_EXEC" ] || [ ! -x "$OPENSURV_EXEC" ]; then
        echo "Error: The specified file does not exist or is not executable."
        exit 1
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
if systemctl is-active opensurv.service >/dev/null 2>&1; then
    echo "OpenSurv service is running!"
else
    echo "Warning: OpenSurv service failed to start. Check logs with: journalctl -u opensurv.service"
fi

echo ""
echo "Setup complete! OpenSurv will now start automatically on system boot."
echo "Use these commands to manage the service:"
echo "  - Check status: sudo systemctl status opensurv.service"
echo "  - Start service: sudo systemctl start opensurv.service"
echo "  - Stop service: sudo systemctl stop opensurv.service"
echo "  - Disable autostart: sudo systemctl disable opensurv.service"
