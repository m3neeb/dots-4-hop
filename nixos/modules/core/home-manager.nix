{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    # not ".bak": fastfetch/config.jsonc.bak already exists
    backupFileExtension = "hm-bak";

    users.aeon = import ../../home;
  };
}
