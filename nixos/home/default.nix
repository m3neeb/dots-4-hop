
{ ... }:

{
  imports = [
    ./fish.nix
    ./starship.nix
    ./lazyvim.nix
  ];

  home.username = "aeon";
  home.homeDirectory = "/home/aeon";
  home.stateVersion = "26.05";
}


