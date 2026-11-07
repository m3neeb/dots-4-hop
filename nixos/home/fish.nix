
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
      pkgs = "sudoedit /etc/nixos/modules/software/packages.nix";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos#nixos";
      fastfetch = "/home/aeon/.config/fastfetch/bin/fastfetch";
      ls = "lsd";
      edit = "sudoedit";
    };
  };
}

