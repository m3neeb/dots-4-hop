{ pkgs, lib, ... }:

{
  programs.dconf.enable = lib.mkDefault true;
  services.gvfs.enable = lib.mkDefault true;

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
  
  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];

    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
      };
    };

    config = {
      umbriel = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "umbriel" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "umbriel" ];
      };
    };
  };
}

