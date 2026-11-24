
{ lib, pkgs, ... }:

let
  profile = null;
in
{
  home.packages = lib.optionals (profile == null) [
    pkgs.floorp-bin
    pkgs.pywalfox-native
  ];

  programs.floorp = lib.mkIf (profile != null) {
    enable = true;
    nativeMessagingHosts = [ pkgs.pywalfox-native ];

    profiles.default = {
      id = 0;
      isDefault = true;
      path = profile;
      userChrome = ./config/floorp/userChrome.css;
      userContent = ./config/floorp/userContent.css;
      settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    };
  };

  xdg.desktopEntries.floorp = {
    name = "Floorp";
    genericName = "Web Browser";
    comment = "Browse the web";
    exec = "floorp %U";
    icon = "floorp";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/xml"
      "application/pdf"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupNotify = true;
    settings.StartupWMClass = "floorp";
  };
}

