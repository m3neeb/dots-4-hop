
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wget
    curl
    starship
    htop
    fetch
    fastfetch
    zoxide
    lsd
    fzf
    jq
    hyprpicker
    wl-clipboard
    astroterm
    glib
    floorp-bin
    pywalfox-native
    vesktop
    zed-editor
    ghostty
    loupe
    mpv
    papers
    abiword
    spotify
    noctalia
    xwayland-satellite
    brightnessctl
    gpu-screen-recorder-ui
  ];
}

