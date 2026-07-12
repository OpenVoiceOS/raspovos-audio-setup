#!/usr/bin/env bats
# Unit tests for lib/audio-utils.sh
# The lib's external commands (aplay, wpctl, pactl, pgrep...) are replaced by
# PATH-prepended stubs in test/stubs, fed from canned output in test/fixtures.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FIXTURES="$REPO_ROOT/test/fixtures"
    STUBS="$REPO_ROOT/test/stubs"
    PATH="$STUBS:$PATH"

    export WPCTL_FIXTURE_DIR="$FIXTURES"
    export WPCTL_STATUS_FIXTURE="$FIXTURES/wpctl_status.txt"
    export PACTL_SINKS_FIXTURE="$FIXTURES/pactl_list_sinks.txt"
    export PACTL_SHORT_SINKS_FIXTURE="$FIXTURES/pactl_short_sinks.txt"

    # Keep the lib's logging out of /tmp during tests
    export LOG_FILE="$BATS_TEST_TMPDIR/test.log"

    # shellcheck source=../lib/audio-utils.sh
    source "$REPO_ROOT/lib/audio-utils.sh"
}

# ---------------------------------------------------------------- aplay parsing

@test "get_card_number finds the bcm2835 headphones card" {
    export APLAY_FIXTURE="$FIXTURES/aplay_all_cards.txt"
    run get_card_number "bcm2835"
    [ "$status" -eq 0 ]
    [ "$output" == "1" ]
}

@test "get_card_number returns empty for an absent card" {
    export APLAY_FIXTURE="$FIXTURES/aplay_all_cards.txt"
    run get_card_number "snd_rpi_proto"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pick_usb_card returns the single USB card" {
    export APLAY_FIXTURE="$FIXTURES/aplay_all_cards.txt"
    run pick_usb_card
    [ "$status" -eq 0 ]
    [ "$output" == "3" ]
}

@test "pick_usb_card picks the LAST card and warns when several USB cards exist" {
    export APLAY_FIXTURE="$FIXTURES/aplay_two_usb.txt"
    run pick_usb_card
    [ "$status" -eq 0 ]
    [[ "$output" == *"Multiple USB soundcards detected"* ]]
    [ "${lines[-1]}" == "2" ]
}

@test "pick_usb_card returns empty when no USB card exists" {
    export APLAY_FIXTURE="$FIXTURES/aplay_onboard_only.txt"
    run pick_usb_card
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ------------------------------------------- fallback priority (USB > HAT > headphones > HDMI)

@test "priority: USB wins over HAT, headphones and HDMI" {
    export APLAY_FIXTURE="$FIXTURES/aplay_all_cards.txt"
    run select_fallback_card
    [ "$output" == "usb 3" ]
}

@test "priority: HAT (user-installed card) wins when no USB is present" {
    export APLAY_FIXTURE="$FIXTURES/aplay_hat_only.txt"
    run select_fallback_card
    [ "$output" == "other 2" ]
}

@test "priority: headphones (bcm2835) win when only onboard cards are present" {
    export APLAY_FIXTURE="$FIXTURES/aplay_onboard_only.txt"
    run select_fallback_card
    [ "$output" == "headphones 1" ]
}

@test "priority: HDMI is the last resort" {
    export APLAY_FIXTURE="$FIXTURES/aplay_hdmi_only.txt"
    run select_fallback_card
    [ "$output" == "hdmi 0" ]
}

@test "priority: empty result when no card at all is detected" {
    export APLAY_FIXTURE="$FIXTURES/aplay_none.txt"
    run select_fallback_card
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------------------------------------------------------------- wpctl parsing

@test "pw_list_sink_ids parses sink IDs from wpctl status (incl. the default sink)" {
    run pw_list_sink_ids
    [ "$status" -eq 0 ]
    [ "${lines[0]}" == "50" ]
    [ "${lines[1]}" == "55" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "pw_card2sink maps an ALSA card index to the PipeWire sink ID" {
    run pw_card2sink 3
    [ "$status" -eq 0 ]
    [ "$output" == "55" ]
}

@test "pw_card2sink returns nothing for an unknown card index" {
    run pw_card2sink 9
    [ -z "$output" ]
}

@test "pw_sink_by_name finds a sink by node.name" {
    run pw_sink_by_name "alsa_output.usb-0d8c_USB_Audio_Device-00.analog-stereo"
    [ "$status" -eq 0 ]
    [ "$output" == "55" ]
}

@test "pw_sink_by_name fails (rc 1) for an unknown node.name" {
    run pw_sink_by_name "auto_combined"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------- pactl parsing

@test "pulse_card2sink maps an ALSA card index to the sink name" {
    run pulse_card2sink 3
    [ "$status" -eq 0 ]
    [ "$output" == "alsa_output.usb-0d8c_USB_Audio_Device-00.analog-stereo" ]
}

@test "pulse_card2sink reports 'Card index not found' for an unknown index" {
    run pulse_card2sink 9
    [ "$status" -eq 0 ]
    [ "$output" == "Card index not found" ]
}

@test "pulse_list_sinks excludes auto_null and auto_combined" {
    run pulse_list_sinks
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" == "alsa_output.platform-bcm2835_audio.stereo-fallback" ]
    [ "${lines[1]}" == "alsa_output.usb-0d8c_USB_Audio_Device-00.analog-stereo" ]
}

# ---------------------------------------------------------------- udev env vars

@test "udev_usb_card extracts the card number from DEVPATH" {
    DEVPATH="/devices/platform/soc/usb/1-1.2:1.0/sound/card3" run udev_usb_card
    [ "$output" == "3" ]
}

@test "udev_usb_card extracts the card number from DEVNAME" {
    DEVNAME="/dev/snd/controlC5" run udev_usb_card
    [ "$output" == "5" ]
}

@test "udev_usb_card returns empty outside of udev" {
    run udev_usb_card
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------------------------------------------------------------- i2c hint

@test "read_i2c_platform returns the hint written by ovos-i2csound" {
    I2C_PLATFORM_FILE="$BATS_TEST_TMPDIR/i2c_platform"
    echo "MARK1" > "$I2C_PLATFORM_FILE"
    run read_i2c_platform
    [ "$output" == "MARK1" ]
}

@test "read_i2c_platform returns empty when the hint file is missing" {
    I2C_PLATFORM_FILE="$BATS_TEST_TMPDIR/does_not_exist"
    run read_i2c_platform
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------------------------------------------------------------- sound server detection

# detect_sound_server probes with pgrep and command -v; run it in a controlled
# PATH containing only the binaries each scenario should "have".
_detect_with() {  # $1: csv of fake binaries to provide
    local dir="$BATS_TEST_TMPDIR/bin_$BATS_TEST_NUMBER"
    mkdir -p "$dir"
    local IFS=','
    for b in $1; do
        printf '#!/bin/sh\nexit 1\n' > "$dir/$b"  # pgrep stub: nothing running
        chmod +x "$dir/$b"
    done
    PATH="$dir" run detect_sound_server
}

@test "detect_sound_server: running pipewire wins" {
    local dir="$BATS_TEST_TMPDIR/bin_pw"
    mkdir -p "$dir"
    printf '#!/bin/sh\n[ "$2" = "pipewire" ] && exit 0 || exit 1\n' > "$dir/pgrep"
    chmod +x "$dir/pgrep"
    PATH="$dir" run detect_sound_server
    [ "$output" == "pipewire" ]
}

@test "detect_sound_server: installed pipewire beats installed pulseaudio" {
    _detect_with "pgrep,pipewire,pulseaudio"
    [ "$output" == "pipewire" ]
}

@test "detect_sound_server: pulse when only pulseaudio is installed" {
    _detect_with "pgrep,pulseaudio"
    [ "$output" == "pulse" ]
}

@test "detect_sound_server: alsa when only alsa-utils are installed" {
    _detect_with "pgrep,aplay,amixer"
    [ "$output" == "alsa" ]
}

@test "detect_sound_server: graceful error when nothing is available" {
    _detect_with "pgrep"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No sound server detected"* ]]
}
