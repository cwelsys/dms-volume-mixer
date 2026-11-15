# Volume Mixer

Standalone volume mixer for [dux-shell](https://github.com/duxlabs-dev/dux-shell). Control master volume, switch audio sinks, and adjust per-app playback levels from your bar.

![screenshot](assets/screenshot.png)

- Streams are grouped per application, with the app's real name and icon resolved from its desktop entry.
- Groups with more than one stream expand to per-stream volume and mute controls.
- Rows show what's playing when the app exposes an MPRIS session.
- Hover an app icon to reset that app back to 100%.
- Hover the master percentage to reset the output back to 100%.
- Sliders snap to round values (quarters by default, every 10 or off) and respond to the scroll wheel.
- Games launched through Steam, Proton or Wine are named and iconed from the game itself.

## Process reading

To identify games and wrapped apps, the mixer reads `/proc/<pid>/stat`, `cmdline` and `environ` for processes playing audio and their parent processes. Only Steam app ids are kept from the environment, nothing is logged, and nothing leaves your machine. Turn off **Identify Apps From Processes** in the plugin settings to skip it.

## Install

Available live in your shell via the [dux-shell plugin registry](https://duxlabs.dev/plugins).

## Contributing

PRs are open.
