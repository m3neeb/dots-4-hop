{ pkgs, ... }:

{
  programs = {
    fish.enable = true;
    git.enable = true;
    neovim.enable = true;
  };

  environment.systemPackages = with pkgs; [
    wget
    curl
    jq
    htop
    fzf
    zoxide
    lsd
    fetch

    ffmpeg
    poppler-utils

    astroterm
    tuios
  ];
}
