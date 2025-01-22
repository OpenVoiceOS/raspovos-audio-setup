#!/bin/bash

# install.sh
# This script installs the necessary services, rules, and scripts for configuring sound on raspOVOS.

# Define paths for the services and scripts
AUTOCONFIGURE_SERVICE_PATH="./autoconfigure_soundcard.service"  # runs on boot
COMBINED_SINKS_SERVICE_PATH="./combine_sinks.service"  # for udev rule usage
SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH="./soundcard-autoconfigure"
USB_AUTOVOLUME_SCRIPT_PATH="./usb-autovolume"
OVOS_AUDIO_DIAGNOSTICS_SCRIPT_PATH="./ovos-audio-diagnostics"
OVOS_AUDIO_SETUP_SCRIPT_PATH="./ovos-audio-setup"
UPDATE_AUDIO_SINKS_SCRIPT_PATH="./combine-sinks"

# Target directories
SYSTEMD_SERVICE_DIR="/etc/systemd/system"

# Install systemd services
echo "Installing systemd service..."

sudo cp "$AUTOCONFIGURE_SERVICE_PATH" "$SYSTEMD_SERVICE_DIR"
sudo cp "$COMBINED_SINKS_SERVICE_PATH" "$SYSTEMD_SERVICE_DIR"

# Reload systemd to recognize the new services
echo "Reloading systemd to apply new services..."
sudo systemctl daemon-reload

# Install other scripts to /usr/local/bin and /usr/libexec
echo "Installing additional scripts..."
sudo cp "$OVOS_AUDIO_SETUP_SCRIPT_PATH" "/usr/local/bin/ovos-audio-setup"
sudo cp "$OVOS_AUDIO_DIAGNOSTICS_SCRIPT_PATH" "/usr/local/bin/ovos-audio-diagnostics"
sudo cp "$UPDATE_AUDIO_SINKS_SCRIPT_PATH" "/usr/libexec/combine-sinks"
sudo cp "$SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH" "/usr/libexec/soundcard-autoconfigure"
sudo cp "$USB_AUTOVOLUME_SCRIPT_PATH" "/usr/libexec/usb-autovolume"

# Ensure scripts are executable
echo "Setting executable permissions for the scripts..."
sudo chmod +x "/usr/local/bin/ovos-audio-setup"
sudo chmod +x "/usr/libexec/combine-sinks"
sudo chmod +x "/usr/local/bin/ovos-audio-diagnostics"
sudo chmod +x "/usr/libexec/soundcard-autoconfigure"
sudo chmod +x "/usr/libexec/usb-autovolume"

# Install dependencies
# TODO - detect sound server and prompt user about migrating to pipewire if needed
apt-get install -y --no-install-recommends wireplumber

# Check if i2csound.service exists
if [ ! -f /etc/systemd/system/i2csound.service ]; then
    echo "/etc/systemd/system/i2csound.service is missing. Automatic audio drivers setup is not available"

    # Prompt the user
    read -p "Would you like to install ovos-i2csound? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Installing ovos-i2csound..."

            # Install dependencies
            apt-get install -y --no-install-recommends i2c-tools

            # Clone and copy files
            git clone https://github.com/OpenVoiceOS/ovos-i2csound /tmp/ovos-i2csound
            cp /tmp/ovos-i2csound/i2c.conf /etc/modules-load.d/i2c.conf
            cp /tmp/ovos-i2csound/bcm2835-alsa.conf /etc/modules-load.d/bcm2835-alsa.conf
            cp /tmp/ovos-i2csound/i2csound.service /etc/systemd/system/i2csound.service
            cp /tmp/ovos-i2csound/ovos-i2csound /usr/libexec/ovos-i2csound
            cp /tmp/ovos-i2csound/99-i2c.rules /usr/lib/udev/rules.d/99-i2c.rules

            # Set permissions
            chmod 644 /etc/systemd/system/i2csound.service
            chmod +x /usr/libexec/ovos-i2csound

            # Enable the service
            ln -s /etc/systemd/system/i2csound.service /etc/systemd/system/multi-user.target.wants/i2csound.service

            echo "ovos-i2csound installed and enabled successfully."
            ;;
        *)
            echo "Skipping ovos-i2csound installation."
            ;;
    esac
else
    echo "i2csound.service is installed!"
fi

# Final message
echo "Installation of 'ovos-audio-setup' completed successfully!"

# Run setup!
/usr/local/bin/ovos-audio-setup
