{ lib, pkgs, ... }:

let
  # Current profile folder name (about:support -> "Profile Folder"), e.g.
  # "ab12cd34.default-release". Back it up first; null leaves Floorp as a plain install.
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
}
