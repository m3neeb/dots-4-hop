{ inputs, pkgs, ... }:

{
  imports = [
    inputs.umbriel.nixosModules.default
    inputs.luciole.nixosModules.default
    inputs.noctalia.nixosModules.default
  ];

  programs = {
    umbriel.enable = true;
    noctalia.enable = true;
    luciole.enable = true;
    gpu-screen-recorder.enable = true;
  };

  environment.systemPackages = with pkgs; [
    xwayland-satellite
    brightnessctl
    hyprpicker
    wl-clipboard
    gpu-screen-recorder-ui
  ];
}
