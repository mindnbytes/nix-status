# Nix Status

A minimal [Noctalia](https://github.com/noctalia-dev/noctalia-shell) plugin that monitors the active NixOS generation, compares system closures on demand, and updates the inputs of a configured Nix flake.

## Setup

1. Copy this directory into your Noctalia plugins directory.
2. Set **Flake directory** in the plugin settings to the directory containing `flake.nix`. An empty setting disables input updates; generation checks and closure comparisons still work.
3. Enable the `Nix Status` plugin and add its widget to your bar.

The widget uses Noctalia's built-in `snowflake` glyph by default. No logo files or template configuration are required. After upgrading a manifest, disable and re-enable the plugin if new settings do not appear.

The panel's **Open Settings** button opens the plugin settings, whether or not a flake directory is already configured. When unconfigured, the update button is disabled and the widget tooltip says that flake updates are not configured; this is not shown as an update error.

The widget shows whether the booted generation differs from the current system and whether the most recent input update changed any inputs. Click it to open controls that:

- Refresh the generation status.
- Compare the booted and current system closures on demand.
- Run a regular `nix flake update --flake FLAKE_DIR` against the configured flake.

The update mutates that flake's `flake.lock` and reports input changes captured from the command output. It requires the `nix` command, network access, and write access to the flake directory. A second run with no newer inputs reports that all inputs are up to date.

## Optional themed NixOS logos

The bundled templates preserve Noctalia palette colors: `on_surface` for normal status, `primary` for updated inputs, and `error` for failed updates.

1. Copy `assets/nix-logo.toml` into the root of your Noctalia configuration directory (normally `~/.config/noctalia/`).
2. Copy the three SVG files from `assets/templates/` into `$XDG_CONFIG_HOME/noctalia/templates/` (normally `~/.config/noctalia/templates/`). Preserve any existing files you have customized rather than overwriting them blindly.
3. Apply the registered templates:

   ```sh
   noctalia msg templates-apply
   ```

4. Enable **Use themed NixOS logos** in the plugin settings, accessible from the panel's **Open Settings** button.

Noctalia normally loads all root-level `*.toml` configuration files automatically. If you use `[include]` with `autoload = false`, explicitly include `nix-logo.toml` in your existing configuration. If you relocate Noctalia's config directory independently of `XDG_CONFIG_HOME`, adjust the TOML's input paths to match where you copied the templates.

The registration file writes rendered logos to `$XDG_CACHE_HOME/noctalia/`, falling back to `~/.cache/noctalia/`. The widget uses the same cache location and watches the selected SVG for changes, so template reapplication updates its colors. If the selected logo is missing, empty, or a directory, the widget falls back to the state-colored snowflake glyph and checks again on subsequent widget updates. A nonempty but malformed SVG is not detected by this fallback; regenerate it or disable themed logos.

The plugin never installs these files into your configuration or runs `templates-apply` automatically. Disabling **Use themed NixOS logos** immediately returns to the glyph on the next widget update; it does not remove your template setup.

## Tests

Run the configuration, icon, parser, and service workflow tests with the standalone Luau interpreter:

```sh
nix shell nixpkgs#luau -c ./scripts/test
```

If `luau` is already available in your environment, run `./scripts/test` directly.

## Branding

The optional templates adapt the NixOS logo to Noctalia palette roles. See [asset attribution](assets/ATTRIBUTION.md) and the bundled [CC BY 4.0 license](assets/CC-BY-4.0.txt). The plugin is not an official NixOS product. Follow the official [NixOS branding guidance](https://nixos.org/branding/) when reusing the artwork.
