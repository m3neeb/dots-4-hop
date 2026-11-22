{ lib, pkgs, ... }:

let
  fastfetch = lib.getExe pkgs.fastfetch;

  # Logo folders (animals/, arch/, geometry/) copied into the Nix store.
  # The wrapper reads them from here directly, so it doesn't depend on
  # anything being linked into ~/.config.
  logos = ./config/fastfetch;

  # Your old ~/.config/fastfetch/bin/fastfetch wrapper (random logo per run),
  # with its hardcoded /usr/bin and /run/current-system paths pointed at the
  # real package, and its logo directory pointed at the store. Named
  # differently so it can't shadow or recurse into fastfetch itself.
  fastfetch-random = pkgs.writeShellScriptBin "fastfetch-random" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils ]}:$PATH
    ${builtins.replaceStrings
      [
        "/usr/bin/fastfetch"
        "/run/current-system/sw/bin/fastfetch"
        "FASTFETCH_DIR=\"\${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch\""
      ]
      [
        fastfetch
        fastfetch
        "FASTFETCH_DIR=\"${logos}\""
      ]
      (builtins.readFile ./config/fastfetch/fastfetch-random.sh)}
  '';
in
{
  home.packages = [ fastfetch-random ];

  # Replace the stale hand-copied scripts (hardcoded /usr/bin/fastfetch) so
  # that every way of launching your wrapper runs this fixed one. The old
  # copies are backed up as *.hm-bak on the first switch.
  # force: the old ones may be symlinks, which home-manager won't back up.
  home.file.".local/bin/fastfetch" = {
    source = "${fastfetch-random}/bin/fastfetch-random";
    force = true;
  };

  # themes/ is written by Noctalia, so it is deliberately not linked here.
  xdg.configFile = {
    "fastfetch/bin/fastfetch" = {
      source = "${fastfetch-random}/bin/fastfetch-random";
      force = true;
    };
    "fastfetch/config.jsonc".source = ./config/fastfetch/config.jsonc;
    "fastfetch/nixos-small.txt".source = ./config/fastfetch/nixos-small.txt;
    "fastfetch/animals".source = ./config/fastfetch/animals;
    "fastfetch/arch".source = ./config/fastfetch/arch;
    "fastfetch/geometry".source = ./config/fastfetch/geometry;
  };
}
