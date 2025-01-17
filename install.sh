#!/bin/bash

# install.sh
# This script installs the necessary services, rules, and scripts for configuring sound on raspOVOS.

# Define paths for the services and scripts
AUTOCONFIGURE_SERVICE_PATH="./autoconfigure_soundcard.service"
COMBINED_SINKS_SERVICE_PATH="./combine_sinks.service"
SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH="./soundcard_autoconfigure"
USB_AUTOVOLUME_SCRIPT_PATH="./usb-autovolume"
OVOS_AUDIO_SETUP_SCRIPT_PATH="./ovos-audio-setup"
UPDATE_AUDIO_SINKS_SCRIPT_PATH="./update-audio-sinks"

# Target directories
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
UDEV_RULES_DIR="/etc/udev/rules.d"
SCRIPTS_DIR="/usr/local/bin"

# Install systemd services
echo "Installing systemd services..."

sudo cp "$AUTOCONFIGURE_SERVICE_PATH" "$SYSTEMD_SERVICE_DIR"
sudo cp "$COMBINED_SINKS_SERVICE_PATH" "$SYSTEMD_SERVICE_DIR"

# Reload systemd to recognize the new services
echo "Reloading systemd to apply new services..."
sudo systemctl daemon-reload

# Enable and start the services
echo "Enabling and starting autoconfigure_soundcard and combine_sinks services..."
sudo systemctl enable --now autoconfigure_soundcard.service

# Install other scripts to /usr/local/bin and /usr/libexec
echo "Installing additional scripts..."
sudo cp "$OVOS_AUDIO_SETUP_SCRIPT_PATH" "/usr/local/bin/ovos-audio-setup"
sudo cp "$UPDATE_AUDIO_SINKS_SCRIPT_PATH" "/usr/libexec/update-audio-sinks"
sudo cp "$SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH" "/usr/libexec/soundcard_autoconfigure"
sudo cp "$USB_AUTOVOLUME_SCRIPT_PATH" "/usr/libexec/usb-autovolume"

# Ensure scripts are executable
echo "Setting executable permissions for the scripts..."

sudo chmod +x "/usr/local/bin/ovos-audio-setup"
sudo chmod +x "/usr/libexec/update-audio-sinks"
sudo chmod +x "/usr/libexec/soundcard_autoconfigure"
sudo chmod +x "/usr/libexec/usb-autovolume"

# Final message
echo "Installation completed successfully!"
