{ ... }:

{
  imports = [
    ./core/system.nix
    ./core/boot.nix
    ./core/nix.nix
    ./core/locale.nix
    ./core/networking.nix
    ./core/memory.nix
    ./core/users.nix
    ./core/home-manager.nix

    ./hardware/audio.nix
    ./hardware/graphics.nix
    ./hardware/peripherals.nix
    ./hardware/power.nix

    ./desktop/theming.nix
    ./desktop/portals.nix
    ./desktop/fonts.nix
    ./desktop/sddm.nix
    ./desktop/shell.nix
    ./desktop/files.nix

    ./programs/cli.nix
    ./programs/apps.nix
    ./programs/python.nix
    ./programs/compat.nix
  ];
}
