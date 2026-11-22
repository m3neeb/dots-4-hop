{ lib, ... }:

let
  # Relative to $HOME. Find yours in Floorp: about:support -> "Profile Folder",
  # e.g. ".floorp/ab12cd34.default-release". Leave null to skip until set.
  profile = null;
in
{
  # Colors come from Pywalfox via Firefox theme variables, so this CSS is
  # fully static and Noctalia's theming is not affected.
  home.file = lib.mkIf (profile != null) {
    "${profile}/chrome/userChrome.css".source = ./config/floorp/userChrome.css;
    "${profile}/chrome/userContent.css".source = ./config/floorp/userContent.css;
  };
}
