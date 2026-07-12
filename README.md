# 🎧🔊 raspOVOS-audio-setup 🎶

**Automatic audio configuration for Raspberry Pi devices running OpenVoiceOS.**

Shell tools and systemd units that keep audio working when hardware changes — plug in a USB soundcard, add a HAT, or move the SD card to different hardware and the right output is selected automatically. They also expose more complex setups (combined outputs, echo cancellation) through a simple menu.

> 💡 **Tip:** Hardware detection and driver setup for I2C HATs (Mark 1, Respeaker, HiFiBerry...) is handled by the companion project [ovos-i2csound](https://github.com/OpenVoiceOS/ovos-i2csound). This repo consumes its detection hints from `/etc/OpenVoiceOS/i2c_platform`.

---

## The tools

| Tool | Installed to | What it does |
|------|--------------|--------------|
| `ovos-audio-setup` | `/usr/local/bin` | Interactive menu (also scriptable: `ovos-audio-setup <choice>`) to select the default soundcard, enable/disable the automation below, and revert everything. |
| `soundcard-autoconfigure` | `/usr/libexec` | Selects the default output card on boot and on USB plug/unplug events. Honors the `ovos-i2csound` hint first, then falls back by fixed priority. |
| `combine-sinks` | `/usr/libexec` | Creates an `auto_combined` sink that plays audio through **all** outputs at once, and sets it as default. Re-run by udev when USB cards come and go. |
| `usb-autovolume` | `/usr/libexec` | Sets a freshly connected USB soundcard to an audible volume (85%). Identifies the card from the udev event environment, with an `aplay -l` scan as fallback. |
| `lib/audio-utils.sh` | `/usr/libexec/ovos-audio-utils.sh` | Shared helper library sourced by all of the above (sound-server detection, card/sink parsing, logging). Not a CLI. |

Plus two systemd units (`autoconfigure_soundcard.service`, `combine_sinks.service` — mutually exclusive with each other) and PipeWire config snippets for switch-on-connect and echo cancellation.

## Soundcard selection priority

`soundcard-autoconfigure` picks the default output in this order:

1. **`ovos-i2csound` hint** — if `/etc/OpenVoiceOS/i2c_platform` names a known platform (Mark 1, WM8960/Respeaker-2mic, HiFiBerry DAC Pro, Google VoiceKit), that card is used.
2. **USB** — last detected USB soundcard (a warning is logged if several are present).
3. **User-installed HAT** — any other card that is neither the onboard headphones nor HDMI.
4. **Headphones** — onboard `bcm2835` jack (not available on Pi 5).
5. **HDMI** — `vc4-hdmi`, as last resort.

## How raspOVOS consumes this

On [raspOVOS](https://github.com/OpenVoiceOS/raspOVOS) images this repo is baked in at image build time: the scripts are installed to `/usr/libexec` + `/usr/local/bin`, `autoconfigure_soundcard.service` is enabled, and udev rules re-trigger the tools on USB sound events. The unit and file names above are a contract with the image build — do not rename them. End users normally only interact with `ovos-audio-setup`.

## Install on a generic system

Works on any Debian-ish system (PipeWire recommended, stock on Raspberry Pi OS Bookworm):

```bash
git clone https://github.com/OpenVoiceOS/raspovos-audio-setup.git
cd raspovos-audio-setup
sudo bash install.sh
```

`install.sh` copies the tools and units into place, offers to install PipeWire when a lesser sound server is detected, offers to install `ovos-i2csound` if missing, and finally launches the `ovos-audio-setup` menu:

```
1) Manually select default soundcard
2) Enable soundcard-autoselect - select default soundcard (on boot)
3) Enable switch-on-connect - if a new soundcard is connected automatically switch to it
4) Enable USB auto-volume - set default volume for USB cards on connection
5) Enable combine-sinks - output audio trough all outputs at once
6) Enable echo cancellation
7) Revert changes - you will be prompted to interactively revert the above actions
8) Exit
```

## Backend support matrix

PipeWire is the primary target (stock on raspOVOS Bookworm images). The `pactl` binary (from `pulseaudio-utils`, preinstalled on the images) talks to PipeWire through `pipewire-pulse`, so the PulseAudio implementations work against PipeWire too.

| Feature | PipeWire | PulseAudio | ALSA only |
|---------|----------|------------|-----------|
| Default soundcard selection | ✅ `wpctl` | ✅ `pactl` | ✅ `~/.asoundrc` |
| Switch-on-connect | ✅ config snippet | ✅ `module-switch-on-connect` | ⚠️ via udev + soundcard-autoconfigure |
| USB auto-volume | ✅ (amixer, backend-independent) | ✅ | ✅ |
| Combine sinks | ✅ `pactl` via pipewire-pulse + `wpctl` default | ✅ `module-combine-sink` | ❌ explicit error, install PipeWire |
| Echo cancellation | ✅ config snippet | ✅ `module-echo-cancel` | ❌ explicit error, install PipeWire |

## 📊 Logging

The tools log to `/tmp` — check these first if you have no audio output:

- `/tmp/autosoundcard.log` — soundcard autoconfiguration
- `/tmp/autovolume-usb.log` — USB volume udev events
- `/tmp/autosink.log` — combined sink creation

## Development

Shared logic lives in `lib/audio-utils.sh`; the five CLIs source it (repo checkout or installed copy). CI enforces both of these:

```bash
# lint (errors only)
shellcheck --severity=error install.sh combine-sinks ovos-audio-setup \
    soundcard-autoconfigure usb-autovolume lib/audio-utils.sh

# unit tests (bats-core; fixtures + PATH-stubbed aplay/wpctl/pactl, no audio hardware needed)
bats test/
```

## Credits

Developed by [TigreGotico](https://tigregotico.pt) for OpenVoiceOS under the [ILENIA](https://proyectoilenia.es) project.

<img src="img.png" width="128"/>

> This work was funded by the Ministerio para la Transformación Digital y de la Función Pública and Plan de
> Recuperación, Transformación y Resiliencia - Funded by EU – NextGenerationEU within the framework of the project
> [ILENIA](https://proyectoilenia.es)
> with reference 2022/TL22/00215337
