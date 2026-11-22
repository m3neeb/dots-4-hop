{ pkgs, ... }:

{
  programs = {
    fish.enable = true;
    git.enable = true;
    neovim.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Basics
    wget
    curl
    jq
    htop
    fzf
    zoxide
    lsd
    fetch
    fastfetch

    # Media / documents
    ffmpeg
    poppler-utils

    # Fun / misc
    astroterm
    tuios
  ];
}
