{ inputs, pkgs, ... }:

{
  imports = [
    inputs.umbriel.nixosModules.default
    inputs.luciole.nixosModules.default
  ];

  programs.umbriel.enable = true;
  programs.luciole.enable = true;
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    noctalia
    xwayland-satellite
    brightnessctl
    hyprpicker
    wl-clipboard
    gpu-screen-recorder-ui
  ];
}
