#!/bin/bash

# install.sh
# This script installs the necessary services, rules, and scripts for configuring sound on raspOVOS.

OVOS_USER="$(getent passwd 1000 | cut -d: -f1)"


# Detects the sound server currently in use on the system.
# Returns the name of the sound server (pipewire, pulse, alsa) or exits with an error if none is found.
detect_sound_server() {
    # Check if PipeWire is installed
    if command -v pipewire > /dev/null; then
        echo "pipewire"
    # Check if PulseAudio is installed
    elif command -v pulseaudio > /dev/null; then
        echo "pulse"
    # Check if ALSA is available
    elif command -v aplay > /dev/null && command -v amixer > /dev/null; then
        echo "alsa"
    else
        echo "No sound server detected"
        exit 1
    fi
}

# Installs a file from the source path to the destination path.
# Arguments:
#   $1 - Source file path
#   $2 - Destination file path
install_file() {
    local src="$1"
    local dest="$2"
    sudo cp "$src" "$dest" && echo "Installed $src to $dest" || echo "Failed to install $src to $dest"
}

# Sets the executable permission for a specified file.
# Arguments:
#   $1 - File path
set_executable() {
    local file="$1"
    sudo chmod +x "$file" && echo "Set executable permission for $file" || echo "Failed to set executable permission for $file"
}

# Detect the sound server in use
SOUND_SERVER=$(detect_sound_server)

# Define paths for the services and scripts
declare -A PATHS=(
    [AUTOCONFIGURE_SERVICE_PATH]="./autoconfigure_soundcard.service"
    [COMBINED_SINKS_SERVICE_PATH]="./combine_sinks.service"
    [SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH]="./soundcard-autoconfigure"
    [USB_AUTOVOLUME_SCRIPT_PATH]="./usb-autovolume"
    [OVOS_AUDIO_SETUP_SCRIPT_PATH]="./ovos-audio-setup"
    [UPDATE_AUDIO_SINKS_SCRIPT_PATH]="./combine-sinks"
)

# Target directories for installation
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
LIBEXEC_DIR="/usr/libexec"

# Install systemd services
echo "Installing systemd services..."
install_file "${PATHS[AUTOCONFIGURE_SERVICE_PATH]}" "$SYSTEMD_SERVICE_DIR"
install_file "${PATHS[COMBINED_SINKS_SERVICE_PATH]}" "$SYSTEMD_SERVICE_DIR"

# Reload systemd to recognize the new services
echo "Reloading systemd to apply new services..."
sudo systemctl daemon-reload

# Install additional scripts
echo "Installing additional scripts..."
install_file "${PATHS[OVOS_AUDIO_SETUP_SCRIPT_PATH]}" "$BIN_DIR/ovos-audio-setup"
install_file "${PATHS[UPDATE_AUDIO_SINKS_SCRIPT_PATH]}" "$LIBEXEC_DIR/combine-sinks"
install_file "${PATHS[SOUNDCARD_AUTOCONFIGURE_SCRIPT_PATH]}" "$LIBEXEC_DIR/soundcard-autoconfigure"
install_file "${PATHS[USB_AUTOVOLUME_SCRIPT_PATH]}" "$LIBEXEC_DIR/usb-autovolume"

# Ensure scripts are executable
echo "Setting executable permissions for the scripts..."
set_executable "$BIN_DIR/ovos-audio-setup"
set_executable "$LIBEXEC_DIR/combine-sinks"
set_executable "$LIBEXEC_DIR/soundcard-autoconfigure"
set_executable "$LIBEXEC_DIR/usb-autovolume"

# Prompt user to install PipeWire if not already installed
if [[ "$SOUND_SERVER" != "pipewire" ]]; then
    echo "Detected sound server: $SOUND_SERVER"
    echo "It is strongly recommended to install PipeWire for better audio management."
    read -p "Would you like to install PipeWire? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            if [[ "$SOUND_SERVER" != "alsa" ]]; then
              echo "Uninstalling pulseaudio..."
              if ! apt-get purge -y pulseaudio; then
                  echo "Failed to uninstall pulseaudio"
                  exit 1
              fi
            fi
            echo "Installing PipeWire..."
            if ! apt-get install -y --no-install-recommends pipewire pipewire-alsa wireplumber; then
                echo "Failed to install PipeWire"
                exit 1
            fi
            # backup existing config
            if [ -f "/home/$OVOS_USER/.asoundrc" ]; then
                if ! mv "/home/$OVOS_USER/.asoundrc" "/home/$OVOS_USER/.asoundrc.bak"; then
                    echo "Failed to backup .asoundrc"
                    exit 1
                fi
            fi
            if ! echo -e "pcm.!default $SOUND_SERVER\nctl.!default $SOUND_SERVER" > "/home/$OVOS_USER/.asoundrc"; then
                echo "Failed to create .asoundrc"
                exit 1
            fi
            if ! chmod 644 "/home/$OVOS_USER/.asoundrc"; then
                echo "Failed to set permissions on .asoundrc"
                exit 1
            fi
            sudo chown $OVOS_USER:$OVOS_USER "/home/$OVOS_USER/.asoundrc"
            echo "PipeWire installed successfully."
            ;;
        *)
            echo "Continuing without PipeWire. The scripts will still work, but some features may be limited or missing."
            ;;
    esac
fi


# Check if i2csound.service exists
if [ ! -f /etc/systemd/system/i2csound.service ]; then
    echo "/etc/systemd/system/i2csound.service is missing. Automatic audio drivers setup is not available."

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
