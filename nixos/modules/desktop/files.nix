{ pkgs, lib, ... }:

{
  services.gvfs.enable = lib.mkDefault true;
  services.tumbler.enable = true;

  environment.systemPackages = with pkgs; [
    glib
    file-roller
    zip
    unzip
    p7zip
  ];
}
