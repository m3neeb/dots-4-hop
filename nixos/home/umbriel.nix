{ inputs, ... }:

let
  parts = [
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

    # Absolute paths: config.toml is a store symlink, so relative includes could
    # miss ~/.config/umbriel and silently drop noctalia.toml. It stays last so
    # its colors win. Optional so a build-time check can't fail on home-only files.
    settings.include.optional.files =
      map (n: "~/.config/umbriel/cfg/${n}.toml") parts
      ++ [ "~/.config/umbriel/noctalia.toml" ];
  };

  xdg.configFile."umbriel/cfg".source = ./config/umbriel/cfg;
}
