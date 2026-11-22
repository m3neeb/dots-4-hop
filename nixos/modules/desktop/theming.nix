{ pkgs, lib, ... }:

{
  programs.dconf.enable = lib.mkDefault true;

  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
    QT_QPA_PLATFORM = "wayland;xcb";
  };

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    papirus-icon-theme
    gtk3
    gtk4
    adw-gtk3
    nwg-look
    libsForQt5.qt5ct
    kdePackages.qt6ct
    kdePackages.kcolorscheme
    kdePackages.qtsvg
  ];
}
