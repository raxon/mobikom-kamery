#!/bin/bash

# OpenSurv Autostart Setup Script for Debian
# This script automatically sets up OpenSurv to start on system boot

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

# Find OpenSurv executable - thorough search
echo "Searching for OpenSurv executable (this may take a minute)..."
OPENSURV_EXEC=""

# Check known binary locations first (faster)
for DIR in /usr/bin /usr/local/bin /opt/opensurv /usr/share/opensurv /home/$CURRENT_USER/opensurv; do
    if [ -x "$DIR/opensurv" ]; then
        OPENSURV_EXEC="$DIR/opensurv"
        break
    fi
done

# If not found, do a more thorough search
if [ -z "$OPENSURV_EXEC" ]; then
    echo "Not found in common locations, performing deeper search..."

    # Use find with timeout to prevent excessive searching
    FOUND_PATH=$(find /usr /opt /home/$CURRENT_USER -name "opensurv" -type f -executable 2>/dev/null | head -n 1)

    if [ -n "$FOUND_PATH" ]; then
        OPENSURV_EXEC="$FOUND_PATH"
    fi
fi

# Check for alternative executable names if still not found
if [ -z "$OPENSURV_EXEC" ]; then
    for ALT_NAME in OpenSurv openSurv OPENSURV; do
        FOUND_PATH=$(find /usr /opt /home/$CURRENT_USER -name "$ALT_NAME" -type f -executable 2>/dev/null | head -n 1)
        if [ -n "$FOUND_PATH" ]; then
            OPENSURV_EXEC="$FOUND_PATH"
            break
        fi
    done
fi

# If still not found, check for process
if [ -z "$OPENSURV_EXEC" ]; then
    echo "Checking currently running processes..."
    PROCESS_PATH=$(ps -ef | grep -i "[o]pensurv" | awk '{print $8}' | head -n 1)
    if [ -n "$PROCESS_PATH" ] && [ -x "$PROCESS_PATH" ]; then
        OPENSURV_EXEC="$PROCESS_PATH"
    fi
fi

# If not found at all, exit
if [ -z "$OPENSURV_EXEC" ]; then
    echo "Error: Could not find OpenSurv executable automatically."
    echo "Please install OpenSurv or run it once before running this script."
    exit 1
fi

echo "Found OpenSurv executable: $OPENSURV_EXEC"

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
