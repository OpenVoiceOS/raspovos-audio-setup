# shellcheck shell=bash
# lib/audio-utils.sh
# Shared helpers for the raspovos-audio-setup tools.
#
# Sourced by: install.sh, ovos-audio-setup, soundcard-autoconfigure,
#             combine-sinks, usb-autovolume
#
# Callers may set before sourcing:
#   LOG_FILE - path the log_message helper appends to (default: /tmp/ovos-audio-setup.log)

# Guard against double sourcing
if [ -n "${_OVOS_AUDIO_UTILS_LOADED:-}" ]; then
    return 0
fi
_OVOS_AUDIO_UTILS_LOADED=1

# Get the username of the first non-system user
OVOS_USER="$(getent passwd 1000 | cut -d: -f1)"

LOG_FILE="${LOG_FILE:-/tmp/ovos-audio-setup.log}"

# Well-known card name fragments (as reported by 'aplay -l')
MK1_CARD_NAME="snd_rpi_proto"                # Mark 1 soundcard
HDMI_CARD_NAME="vc4-hdmi"                    # HDMI soundcard
HEADPHONES_CARD_NAME="bcm2835"               # Onboard soundcard, not available on RPi 5
GOOGLE_VOICEKIT_V1="snd_rpi_googlevoicehat"  # User manually configures this soundcard
RESPEAKER_2MIC="wm8960-soundcard"            # Respeaker 2mic card
HIFIBERRY_DAC_PRO="snd_rpi_hifiberry_dacplus"

# ovos-i2csound hint file
I2C_PLATFORM_FILE="/etc/OpenVoiceOS/i2c_platform"

# Function to log messages to both console and a log file
# Arguments:
#   $1: Message to log
log_message() {
    echo "$1"
    echo "$(date) - $1" >> "$LOG_FILE"
}

# Function to handle errors
# Logs an error message and exits the script
# Arguments:
#   $1: Line number where the error occurred
#   $2: Error code
error_handler() {
    local line_no=$1
    local error_code=$2
    log_message "Error (code: ${error_code}) occurred on line ${line_no}"
    exit "${error_code}"
}

# Function to check if the script is running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Run a command as the OVOS user when we are root (e.g. from udev/systemd),
# otherwise run it directly.
run_as_ovos_user() {
    if is_root; then
        runuser -u "$OVOS_USER" -- "$@"
    else
        "$@"
    fi
}

# Function to detect the active sound server (PipeWire, PulseAudio, or ALSA)
# Prefers a *running* server over a merely installed one.
# Returns the sound server type as a string: pipewire | pulse | alsa
detect_sound_server() {
    # Check for a running server first
    if pgrep -x pipewire > /dev/null 2>&1; then
        echo "pipewire"
    elif pgrep -x pulseaudio > /dev/null 2>&1; then
        echo "pulse"
    # Fall back to what is installed (early boot, chroot at image build time...)
    elif command -v pipewire > /dev/null; then
        echo "pipewire"
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

# Read the ovos-i2csound platform hint
# Returns the hint string, or "" if the file does not exist
read_i2c_platform() {
    if [ -f "$I2C_PLATFORM_FILE" ]; then
        cat "$I2C_PLATFORM_FILE"
    else
        echo ""
    fi
}

# Get the ALSA card number for the first card whose 'aplay -l' line matches $1
# Arguments:
#   $1: Card name fragment (e.g. "snd_rpi_proto")
# Returns: card number, or "" if not found
get_card_number() {
    local card_name="$1"
    aplay -l | grep "$card_name" | awk '{print $2}' | cut -d':' -f1 | head -n 1
}

# List the card numbers of all USB soundcards, one per line
list_usb_cards() {
    aplay -l | grep "card" | grep -i "usb" | awk '{print $2}' | cut -d':' -f1
}

# Pick the USB card to use: the last one detected wins when there are several
# Returns: card number, or "" if no USB card is present
pick_usb_card() {
    local usb_cards
    usb_cards=$(list_usb_cards)
    if [ -z "$usb_cards" ]; then
        echo ""
        return 0
    fi
    local card_count
    card_count=$(echo "$usb_cards" | wc -l)
    if [ "$card_count" -gt 1 ]; then
        log_message "Warning: Multiple USB soundcards detected. Using the last detected card."
    fi
    echo "$usb_cards" | tail -n 1
}

# Extract the ALSA card number for the device that triggered a udev rule,
# from the environment udev passes to RUN+= scripts (DEVPATH like
# ".../sound/card2" or DEVNAME like "/dev/snd/controlC2").
# Returns: card number, or "" when not running from udev (or no match)
udev_usb_card() {
    local card=""
    if [[ "${DEVPATH:-}" =~ /sound/card([0-9]+) ]]; then
        card="${BASH_REMATCH[1]}"
    elif [[ "${DEVNAME:-}" =~ controlC([0-9]+) ]]; then
        card="${BASH_REMATCH[1]}"
    fi
    echo "$card"
}

# Select the fallback soundcard following the fixed priority:
#   USB > user-installed HAT (any non-onboard card) > headphones (bcm2835) > HDMI
# Returns: "<type> <card_number>" (type: usb|other|headphones|hdmi), or "" if none
select_fallback_card() {
    local card
    card=$(pick_usb_card)
    if [ -n "$card" ]; then
        echo "usb $card"
        return 0
    fi
    # Any other non-onboard soundcard (prioritize user-installed cards over onboard ones)
    card=$(aplay -l | grep "card" | grep -v -i "$HEADPHONES_CARD_NAME" | grep -v -i "$HDMI_CARD_NAME" | awk '{print $2}' | cut -d':' -f1 | head -n 1)
    if [ -n "$card" ]; then
        echo "other $card"
        return 0
    fi
    # Onboard BCM soundcard (headphones)
    card=$(aplay -l | grep "card" | grep -i "$HEADPHONES_CARD_NAME" | awk '{print $2}' | cut -d':' -f1 | head -n 1)
    if [ -n "$card" ]; then
        echo "headphones $card"
        return 0
    fi
    # HDMI as last resort
    card=$(aplay -l | grep "card" | grep -i "$HDMI_CARD_NAME" | awk '{print $2}' | cut -d':' -f1 | head -n 1)
    if [ -n "$card" ]; then
        echo "hdmi $card"
        return 0
    fi
    echo ""
}

# List PipeWire sink IDs from 'wpctl status', one per line
pw_list_sink_ids() {
    wpctl status | awk '
        /├─ Sinks:/ {capture = 1; next}
        /^ ├─|^ └─|^$/ {capture = 0}
        capture {
            if ($2 == "*") {
                gsub(/\.$/, "", $3)
                print $3
            }
            if ($2 ~ /^[0-9]+\.$/) {
                gsub(/\.$/, "", $2)
                print $2
            }
        }
    '
}

# Map an ALSA card index to a PipeWire sink ID (via wpctl)
# Arguments:
#   $1: ALSA card index
# Returns: sink ID(s) whose api.alsa.pcm.card matches
pw_card2sink() {
    local card_idx="$1"
    local sink cidx
    for sink in $(pw_list_sink_ids); do
        cidx=$(wpctl inspect "$sink" | grep -i "api.alsa.pcm.card" | awk -F'"' '{print $2}')
        if [ "$cidx" == "$card_idx" ]; then
            echo "$sink"
        fi
    done
}

# Find the PipeWire sink ID whose node.name matches $1 (via wpctl)
# Arguments:
#   $1: node.name to look for (e.g. "auto_combined")
# Returns: sink ID, return code 1 if not found
pw_sink_by_name() {
    local name="$1"
    local sink node_name
    for sink in $(pw_list_sink_ids); do
        node_name=$(wpctl inspect "$sink" | grep -i "node.name" | awk -F'"' '{print $2}')
        if [ "$node_name" == "$name" ]; then
            echo "$sink"
            return 0
        fi
    done
    return 1
}

# Map an ALSA card index to a PulseAudio sink name (via pactl)
# Arguments:
#   $1: ALSA card index
# Returns: sink name, or "Card index not found"
pulse_card2sink() {
    local card_index="$1"
    run_as_ovos_user pactl list sinks | awk -v card_index="$card_index" '
      BEGIN {found = 0}
      /Name: / { name = $2 }
      /api.alsa.card/ {
          gsub(/"/, "", $3)
          if ($3 == card_index) {
              print name
              found = 1
          }
      }
      END { if (found == 0) { print "Card index not found" } }'
}

# List sink names from 'pactl list short sinks', excluding virtual
# auto_combined / auto_null sinks, one per line
pulse_list_sinks() {
    pactl list short sinks | awk '{print $2}' | grep -v 'auto_combined' | grep -v 'auto_null'
}
