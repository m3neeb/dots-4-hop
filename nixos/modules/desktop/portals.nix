{ pkgs, ... }:

{
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];

    # Replaces ~/.config/xdg-desktop-portal/portals.conf
    config.common = {
      default = [ "luciole" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "luciole" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "luciole" "gtk" ];
    };

    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
      };
    };
  };
}
