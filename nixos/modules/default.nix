{ ... }:

{
  imports = [
    ./apps/thunar.nix
    
    ./desktop/desktop.nix
    ./desktop/fonts.nix
    ./desktop/locale.nix

    ./functionality/audio.nix
    ./functionality/drivers.nix
    ./functionality/hardware.nix
    ./functionality/networking.nix

    ./software/nixconf.nix
    ./software/packages.nix
    ./software/programs.nix
    ./software/python.nix
    ./software/services.nix
    
    ./system/boot.nix
    ./system/sddm.nix
    ./system/users.nix
  ];
}
