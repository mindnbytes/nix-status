# Nix Status

A minimal [Noctalia](https://github.com/noctalia-dev/noctalia-shell) plugin that monitors the active NixOS generation, compares system closures on demand, and checks a Nix flake for input updates without modifying its current `flake.lock`.

## Setup

1. Copy this directory into your Noctalia plugins directory.
2. Set `FLAKE_DIR` in `service.luau` to your flake directory.
3. Add the NixOS logo variants (`nix-logo.svg`, `nix-logo-updates.svg`, and `nix-logo-error.svg`) to your Noctalia templates, declare them in Noctalia's `config.toml`, then run `noctalia msg templates-apply`.
4. Enable the `Nix Status` plugin and add its widget to your bar.

The widget indicates when the booted generation differs from the current system or flake input updates are available. Click it to:

- Refresh the generation status.
- Compare the booted and current system closures on demand.
- Check for flake input updates.

Update checks require the `nix` command and network access.

## Tests

Run the parser and flake-lock comparison tests with the standalone Luau interpreter:

```sh
nix shell nixpkgs#luau -c ./scripts/test
```

If `luau` is already available in your environment, run `./scripts/test` directly.

## Branding

The widget uses the NixOS logo for clear visual identification. Use artwork from the official [NixOS branding page](https://nixos.org/branding/) and follow its branding and licensing guidance.
