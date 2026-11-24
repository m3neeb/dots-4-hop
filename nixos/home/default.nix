{ ... }:

{
  imports = [
    ./fish.nix
    ./starship.nix
    ./lazyvim.nix

    ./fastfetch.nix
    ./ghostty.nix
    ./gtk.nix
    ./umbriel.nix
    ./floorp.nix
    ./mpv.nix
    ./desktop-entries.nix
  ];

  home.username = "aeon";
  home.homeDirectory = "/home/aeon";
  home.stateVersion = "26.05";
}
