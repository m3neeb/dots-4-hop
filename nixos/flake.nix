{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim.url = "github:pfassina/lazyvim-nix";

    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    sonora.url = "github:sonorahq/sonora";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, lazyvim, umbriel, sonora, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
        inputs.umbriel.nixosModules.default
        home-manager.nixosModules.home-manager

        {
          environment.systemPackages = [
            inputs.sonora.packages.x86_64-linux.sonora-bin
          ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.extraSpecialArgs = {
            inherit inputs;
          };

          home-manager.users.aeon = {
            imports = [ ./home ];

            home.packages = [
              home-manager.packages.x86_64-linux.home-manager
            ];
          };
        }
      ];
    };

    homeConfigurations.aeon = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      extraSpecialArgs = {
        inherit inputs;
      };

      modules = [
        ./home/default.nix
      ];
    };
  };
}
