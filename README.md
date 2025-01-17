# 🎧🔊 raspOVOS-audio-setup 🎶

**Easily configure audio for Raspberry Pi devices running OpenVoiceOS.**  

This repository provides scripts and systemd services to manage audio configurations, simplifying tasks like setting default soundcards, combining audio sinks, and managing USB soundcard volumes. It's designed for users looking to optimize their Raspberry Pi's audio capabilities without diving deep into manual setup.  

---

## Features:
- Auto-detect and configure default soundcards, prioritizing external Hats and USB devices.
- Combine multiple audio sinks for seamless playback across devices.
- Revert all audio-related configurations to the default state with a single command.
- Ensure compatibility by managing mutually exclusive services (`autoconfigure_soundcard.service` and `combine_sinks.service`).

> 💡 **Tip:** Want automatic hardware detection and driver setup? Check out [ovos-i2csound](https://github.com/OpenVoiceOS/ovos-i2csound), designed for Raspberry Pi-specific hardware like Mycroft Mark 1 and Respeaker.

---

## 📂 Files in this Repository

1. **autoconfigure_soundcard.service**  
   Automatically configures the default soundcard based on the detected hardware on boot and when USB devices are plugged in.  

2. **combine_sinks.service**  
   Systemd service that combines multiple audio sinks into one, allowing seamless audio output across multiple devices. This service is mutually exclusive with `autoconfigure_soundcard.service`. 

3. **install.sh**  
   Installation script that sets up all necessary files and configurations, including copying scripts to the appropriate directories and enabling systemd services. 

4. **ovos-audio-setup**  
   Main script that provides an interactive setup menu to configure the default soundcard, enable automatic soundcard configuration, enable combined audio sinks, or revert all changes.

5. **soundcard_autoconfigure**  
   Automatically detects and configures the default soundcard, prioritizing USB soundcards. Falls back to onboard soundcards if no external soundcards are found. (`Mark1 > USB > other > Headphones > HDMI`)

6. **update-audio-sinks**  
   Manages PulseAudio/PipeWire sinks, specifically for combining audio sinks when multiple devices are detected. 

7. **usb-autovolume**  
   Adjusts the volume of USB soundcards and recreates the combined audio sink to include the new USB soundcard.

---

## How to Use

### 🛠️ Install

Run the following command to install all necessary scripts and enable the systemd services:

```bash
git clone https://github.com/your-repo/raspOVOS-audio-setup.git
cd raspOVOS-audio-setup
sudo bash install.sh
```

This will copy the scripts to the appropriate directories, set executable permissions, and enable the required systemd services. 

### 🔧🎵 Audio Setup

To run the script, execute the following:

```bash
/usr/local/bin/ovos-audio-setup
```

Follow the prompts to choose an option based on your needs.  

The script provides the following choices:

- **1) Set default soundcard**  
   Manually set the default soundcard. It will list all available soundcards and prompt you to choose one. Selecting this option will disable any active `combine_sinks.service` or `autoconfigure_soundcard.service`.  

- **2) Autoconfigure default soundcard**  
   Automatically configures the default soundcard based on the detected hardware (USB or onboard soundcard). The `autoconfigure_soundcard.service` will be enabled, and any active `combine_sinks.service` will be disabled.  

- **3) Enable combined audio sinks**  
   Enables the combination of multiple audio sinks into one unified audio output. The `combine_sinks.service` will be enabled, and the `autoconfigure_soundcard.service` will be disabled.  

- **4) Revert changes**  
   Reverts all audio configurations to their default state. This disables any active services and restores original system settings.  

- **5) Exit**  
   Exit the setup process without making changes.  

---

## 📊 Logging

- All scripts generate logs, which are saved to the `/tmp` directory:
  - **/tmp/autosoundcard.log** (for soundcard autoconfiguration)
  - **/tmp/autovolume-usb.log** (for USB soundcard udev events)
  - **/tmp/autosink.log** (for sink creation and merging events)

Check these logs for troubleshooting if you have no audio output.  

---

## Example Logs

Below is a sample log output for typical operations:  

```bash
(ovos) ovos@raspOVOS:~ $ tail -f /tmp/*.log
==> /tmp/autosoundcard.log <==
Fri 17 Jan 11:42:46 WET 2025 - **** List of PLAYBACK Hardware Devices ****
card 0: Headphones [bcm2835 Headphones], device 0: bcm2835 Headphones [bcm2835 Headphones]
  Subdevices: 8/8
  Subdevice #0: subdevice #0
  Subdevice #1: subdevice #1
  Subdevice #2: subdevice #2
  Subdevice #3: subdevice #3
  Subdevice #4: subdevice #4
  Subdevice #5: subdevice #5
  Subdevice #6: subdevice #6
  Subdevice #7: subdevice #7
card 1: Device [USB Audio Device], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 2: vc4hdmi [vc4-hdmi], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 3: sndrpiproto [snd_rpi_proto], device 0: WM8731 HiFi wm8731-hifi-0 [WM8731 HiFi wm8731-hifi-0]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
Fri 17 Jan 11:42:48 WET 2025 - Mark 1 soundcard detected by ovos-i2csound.
Fri 17 Jan 11:42:48 WET 2025 - Detected CARD_NUMBER for Mark 1 soundcard: 3
Fri 17 Jan 11:42:48 WET 2025 - Configuring ALSA default card
Fri 17 Jan 11:42:48 WET 2025 - Running as user, modifying ~/.asoundrc
Fri 17 Jan 11:42:48 WET 2025 - ALSA default card set to: 3

==> /tmp/autovolume-usb.log <==
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 2: vc4hdmi [vc4-hdmi], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 3: sndrpiproto [snd_rpi_proto], device 0: WM8731 HiFi wm8731-hifi-0 [WM8731 HiFi wm8731-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
Fri Jan 17 11:42:43 WET 2025 - USB audio device detected. Soundcard index: 1
Fri Jan 17 11:42:43 WET 2025 - Volume set to 85% on card 1, control 'Speaker'


==> /tmp/autosink.log  <==
Setting up audio output as combined sinks
Running as user
Sinks before action: 52	alsa_output.platform-bcm2835_audio.stereo-fallback	PipeWire	s16le 2ch 48000Hz	SUSPENDED
53	alsa_output.platform-3f902000.hdmi.hdmi-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
54	alsa_output.platform-soc_sound.stereo-fallback	PipeWire	s32le 2ch 48000Hz	RUNNING
56	alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo	PipeWire	s16le 2ch 48000Hz	SUSPENDED
auto_combined sink missing
Total sinks: 4
Combined sink created with outputs: alsa_output.platform-bcm2835_audio.stereo-fallback,alsa_output.platform-3f902000.hdmi.hdmi-stereo,alsa_output.platform-soc_sound.stereo-fallback,alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo (module ID: 536870916)
Sinks after action: 52	alsa_output.platform-bcm2835_audio.stereo-fallback	PipeWire	s16le 2ch 48000Hz	SUSPENDED
53	alsa_output.platform-3f902000.hdmi.hdmi-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
54	alsa_output.platform-soc_sound.stereo-fallback	PipeWire	s32le 2ch 48000Hz	RUNNING
56	alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo	PipeWire	s16le 2ch 48000Hz	SUSPENDED
108	auto_combined	PipeWire	float32le 2ch 48000Hz	SUSPENDED

```

---

Enjoy configuring your audio setup with ease! 🎉  



