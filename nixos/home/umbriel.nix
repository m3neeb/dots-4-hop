{ inputs, lib, ... }:

let
  # Each file owns distinct top-level tables, so a plain merge is enough.
  parts = map (n: import (./config/umbriel + "/${n}.nix")) [
    "animation"
    "appearance"
    "autostart"
    "input"
    "key"
    "layer-rule"
    "layout"
    "outputs"
    "overview"
    "workspaces"
    "rules"
    "events"
  ];
in
{
  imports = [ inputs.umbriel.homeModules.default ];

  programs.umbriel = {
    enable = true;

    settings = lib.foldl' lib.recursiveUpdate {
      # The main file is applied last, so noctalia.toml has to be included and
      # not merged in: it owns colors.overview (dropped from overview.nix for
      # that reason) and its own window rules.
      include.optional.files = [ "~/.config/umbriel/noctalia.toml" ];
    } parts;
  };
}
