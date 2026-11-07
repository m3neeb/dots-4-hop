{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];

  fonts.fontconfig.defaultFonts = {
    emoji = [ "Noto Color Emoji" ];
  };
}
