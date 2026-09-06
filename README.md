# Nix Status

A minimal [Noctalia](https://github.com/noctalia-dev/noctalia-shell) plugin that monitors the active NixOS generation, compares system closures on demand, and updates the inputs of a configured Nix flake.

## Setup

1. Copy this directory into your Noctalia plugins directory.
2. Set **Flake directory** in the plugin settings to the directory containing `flake.nix`. An empty setting disables input updates; generation checks and closure comparisons still work.
3. Add the NixOS logo variants (`nix-logo.svg`, `nix-logo-updates.svg`, and `nix-logo-error.svg`) to your Noctalia templates, declare them in Noctalia's `config.toml`, then run `noctalia msg templates-apply`.
4. Enable the `Nix Status` plugin and add its widget to your bar.

The panel's **Open Settings** button opens the plugin settings, whether or not a flake directory is already configured. When unconfigured, the update button is disabled and the widget tooltip says that flake updates are not configured; this is not shown as an update error.

The widget shows whether the booted generation differs from the current system and whether the most recent input update changed any inputs. Click it to open controls that:

- Refresh the generation status.
- Compare the booted and current system closures on demand.
- Run a regular `nix flake update --flake FLAKE_DIR` against the configured flake.

The update mutates that flake's `flake.lock` and reports input changes captured from the command output. It requires the `nix` command, network access, and write access to the flake directory. A second run with no newer inputs reports that all inputs are up to date.

## Tests

Run the closure-diff and Nix update-output parser tests with the standalone Luau interpreter:

```sh
nix shell nixpkgs#luau -c ./scripts/test
```

If `luau` is already available in your environment, run `./scripts/test` directly.

## Branding

The widget uses the NixOS logo for clear visual identification. Use artwork from the official [NixOS branding page](https://nixos.org/branding/) and follow its branding and licensing guidance.
