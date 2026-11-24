{ lib, pkgs, ... }:

let
  fastfetch = lib.getExe pkgs.fastfetch;

  # logos are read straight from the store, not through ~/.config
  logos = ./config/fastfetch;

  # random-logo wrapper; named differently so it can't recurse into fastfetch
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
  # themes/ is Noctalia's, not declared here
  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      logo = {
        source = "~/.config/fastfetch/arch/rising.txt";
        color = {
          "1" = "#3584e4";
          "2" = "#1b467c";
          "3" = "yellow";
          "4" = "magenta";
          "5" = "green";
          "6" = "red";
          "7" = "white";
          "8" = "black";
          "9" = "default";
        };
        padding = {
          top = 1;
          right = 6;
          bottom = 1;
        };
      };
      display = {
        separator = "     ";
        color = {
          keys = "#3584e4";
          title = "#1b467c";
        };
        percent = {
          color = {
            green = "#ffffff";
            yellow = "#8fbbf0";
            red = "#c01c28";
          };
        };
      };
      modules = [
        {
          type = "title";
          format = "{#32}{1}{#90} @ {#34}aeofetch";
        }
        "break"
        {
          type = "os";
          key = "{#34}󱄅  os    ";
          format = "NixOS";
        }
        {
          type = "wm";
          key = "{#35}  wm    ";
          format = "Umbriel";
        }
        {
          type = "shell";
          key = "{#32}  shell ";
          format = "{exe-name}";
        }
        {
          type = "uptime";
          key = "{#33}󰅐  uptime";
          format = "{hours}h {minutes}m";
        }
        {
          type = "cpu";
          key = "{#31}  cpu   ";
          format = "{name}";
        }
        "break"
        {
          type = "custom";
          format = "{#33}󰮯   {#32}󰊠 {#31}󰊠 {#33}󰊠 {#35}󰊠 {#36}󰊠 {#90}󰊠 {#34}󰊠 {#93}󰊠 {#37}󰊠  ";
        }
        "break"
      ];
    };
  };

  home.packages = [ fastfetch-random ];

  # replaces the old hand-copied scripts; force because they may be symlinks
  home.file.".local/bin/fastfetch" = {
    source = "${fastfetch-random}/bin/fastfetch-random";
    force = true;
  };

  xdg.configFile = {
    "fastfetch/bin/fastfetch" = {
      source = "${fastfetch-random}/bin/fastfetch-random";
      force = true;
    };
    "fastfetch/nixos-small.txt".source = ./config/fastfetch/nixos-small.txt;
    "fastfetch/animals".source = ./config/fastfetch/animals;
    "fastfetch/arch".source = ./config/fastfetch/arch;
    "fastfetch/geometry".source = ./config/fastfetch/geometry;
  };
}
