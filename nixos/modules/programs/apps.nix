{ inputs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Browser
    floorp-bin
    pywalfox-native

    # Communication / media
    vesktop
    spotify
    mpv
    loupe
    papers

    # Editors / terminals
    zed-editor
    ghostty

    # From flake inputs
    inputs.sonora.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
