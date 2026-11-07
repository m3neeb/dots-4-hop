{ ... }:

{
  nixpkgs.config.allowUnfree = true;

  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.git.enable = true;
  programs.gpu-screen-recorder.enable = true;
  programs.neovim.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  }; 
  programs.umbriel = {
    enable = true;
  };
}
