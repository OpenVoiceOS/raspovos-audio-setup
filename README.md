# raspOVOS-audio-setup

This repository provides a set of scripts and services designed to set up and manage audio configurations for Raspberry Pi-based devices running OpenVoiceOS.

It helps with configuring default soundcards, automatically setting up audio sinks, and adjusting USB soundcard volumes. 
The setup also ensures that conflicting services are disabled, as the `autoconfigure_soundcard` and `combine_sinks` services are mutually exclusive.

## Files in this Repository

1. **autoconfigure_soundcard.service**  
   Automatically configures the default soundcard based on the detected hardware. on boot and when USB devices are plugged

2. **combine_sinks.service**  
   Systemd service that combines multiple audio sinks into one, allowing seamless audio output across multiple devices. This service is mutually exclusive with `autoconfigure_soundcard.service`.

3. **install.sh**  
   Installation script that sets up all necessary files and configurations, including copying scripts to the appropriate directories and enabling systemd services.

4. **ovos-audio-setup**  
   A main script that provides an interactive setup menu to configure the default soundcard, enable automatic soundcard configuration, or enable combined audio sinks.

5. **soundcard_autoconfigure**  
   Automatically detects and configures the default soundcard, prioritizing USB soundcards and Mark 1 soundcards when connected. It falls back to onboard soundcards if no external soundcards are found.

6. **update-audio-sinks**  
   Manages PulseAudio/PipeWire sinks, specifically for combining audio sinks when multiple devices are detected.

7. **usb-autovolume**  
   Adjusts the volume of USB soundcards automatically when they are connected, ensuring the correct volume is set for each device.


## How to Use

### 1. Install the Setup

Run the following command to install all necessary scripts and enable the systemd services:

```bash
sudo ./install.sh
```

This will copy the scripts to the appropriate directories, set executable permissions, and enable the required systemd services.

### 2. Audio Setup Options

You can configure the audio setup using the provided script, `ovos-audio-setup`. It allows you to choose from several options:

- **1) Set default soundcard**  
   This option allows you to manually set the default soundcard. It will list all available soundcards and prompt you to choose one. If you select this option, any active `combine_sinks.service` or `autoconfigure_soundcard.service` will be disabled.

- **2) Autoconfigure default soundcard**  
   This option automatically configures the default soundcard based on the detected hardware (USB or onboard soundcard). The `autoconfigure_soundcard.service` will be enabled, and any active `combine_sinks.service` will be disabled.

- **3) Enable combined audio sinks**  
   This option enables the combination of multiple audio sinks into one unified audio output. The `combine_sinks.service` will be enabled, and the `autoconfigure_soundcard.service` will be disabled.

- **4) Exit**  
   Exit the setup process without making changes.

To run the script, execute the following:

```bash
/usr/local/bin/ovos-audio-setup
```

Follow the prompts to choose an option based on your needs.

### Logging

- All scripts generate logs, which are saved to the `/tmp` directory:
  - **/tmp/autosink-usb.log** (for USB soundcard udev events)
  - **/tmp/autosink.log** (for sink creation and merging events)

You can check these logs for troubleshooting or status updates.