{ ... }:

{
  hardware.bluetooth.enable = true;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

}
