{ ... }:

{
  users.users.aeon = {
    isNormalUser = true;
    description = "Aeon";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "audio"
      "video"
    ];
  };
}
