{ ... }:

{
  programs.nix-ld.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  services.flatpak.enable = true;
}
