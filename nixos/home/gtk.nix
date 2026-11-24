{ ... }:

{
  gtk = {
    enable = true;

    gtk2.enable = false;

    # package = null: theme, icons and cursor come from modules/desktop/theming.nix
    theme.name = "adw-gtk3-dark";
    iconTheme.name = "Papirus";
    cursorTheme = {
      name = "Adwaita";
      size = 24;
    };
    font = {
      name = "Iosevka Nerd Font";
      size = 11;
    };

    gtk3 = {
      extraConfig = {
        gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
        gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
        gtk-button-images = 0;
        gtk-menu-images = 0;
        gtk-sound-theme-name = "freedesktop";
        gtk-enable-event-sounds = 1;
        gtk-enable-input-feedback-sounds = 0;
        gtk-error-bell = 1;
        gtk-xft-antialias = 1;
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintslight";
        gtk-xft-rgba = "rgb";
        gtk-application-prefer-dark-theme = 1;
      };

      # noctalia.css is Noctalia's; only imported here
      extraCss = ''
        * { border-radius: 0; box-shadow: none; }

        @import url("noctalia.css");
      '';
    };

    gtk4 = {
      # gtk4.theme stays unset: it injects the theme's CSS and could fight Noctalia's colors
      extraConfig = {
        gtk-theme-name = "adw-gtk3-dark";
        gtk-sound-theme-name = "freedesktop";
        gtk-error-bell = 1;
        gtk-application-prefer-dark-theme = 1;
      };

      extraCss = ''
        @import url("borders.css");

        @import url("noctalia.css");
      '';
    };
  };

  xdg.configFile."gtk-4.0/borders.css".source = ./config/gtk-4.0/borders.css;
}
