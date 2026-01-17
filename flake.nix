{
  description = "VM base images for spoonstech, built with nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
#    incus-raw-img = {
#      url = "file+https://images.linuxcontainers.org/os/202601152002/x86_64/IncusOS_202601152002.img.gz";
#      flake = false;
#    };
#    sd-garnix = {
#      url = "git+https://codeberg.org/srd424/garnix-builds.git";
#    };
    spoons-flakes = {
      url = "git+https://forge.deathbycomputers.co.uk/spoons.technology/nixos-modules.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, spoons-flakes, nixos-generators }:
  {
    packages.x86_64-linux.nixos-base = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      format = "qcow-efi";
      modules = [
        {
          spoons.nixos-image.authorizedKey = (builtins.readFile ./authorized_key);
          system.stateVersion = "25.11";
        }
        spoons-flakes.nixosModules.nixos-base
      ];
    };
  };
}

# vim: set ts=2 sw=2 et sta:
