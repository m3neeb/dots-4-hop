
{ inputs, pkgs, ... }:

{
  imports = [
    inputs.lazyvim.homeManagerModules.default
  ];

  programs.lazyvim = {
    enable = true;

    extras = {
      lang.nix.enable = true;
    };

    extraPackages = with pkgs; [
      nixd
      statix
      lua-language-server
      stylua
    ];
  };
}

