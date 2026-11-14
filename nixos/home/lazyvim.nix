
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

    config = {
      options = ''
        vim.g.loaded_2html_plugin = 1
        vim.g.trouble_lualine = false
      '';
    };

    extraPackages = with pkgs; [
      nixd
      statix
      lua-language-server
      stylua
    ];
  };
}

