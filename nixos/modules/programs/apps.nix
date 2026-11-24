{ inputs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # floorp, ghostty, mpv and fastfetch are installed from home/
    vesktop
    spotify
    loupe
    papers

    zed-editor

    inputs.sonora.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
