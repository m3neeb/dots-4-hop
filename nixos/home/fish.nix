{ ... }:

{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting ""
      set -gx EDITOR nvim
      set -gx VISUAL nvim
    '';

    shellAliases = {
      pkgs = "sudoedit /etc/nixos/modules/programs/apps.nix";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      fastfetch = "fastfetch-random";
      ls = "lsd";
      edit = "sudoedit";
    };
  };
}
