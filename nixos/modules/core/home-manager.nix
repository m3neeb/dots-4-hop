{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    # Existing hand-written dotfiles get renamed to *.hm-bak on first switch
    # instead of aborting activation. (Not ".bak": you already have a
    # fastfetch/config.jsonc.bak, which would collide.)
    backupFileExtension = "hm-bak";

    users.aeon = import ../../home;
  };
}
