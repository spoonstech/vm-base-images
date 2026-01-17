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
    garnix-actions = {
      url = "github:garnix-io/actions";
    };
  };

  outputs = { self, nixpkgs, spoons-flakes, nixos-generators, garnix-actions }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.nixos-base = nixos-generators.nixosGenerate {
      #system = "x86_64-linux";
      inherit system;
      format = "qcow-efi";
      modules = [
        {
          spoons.nixos-image.authorizedKeys = (pkgs.lib.splitString "\n" (builtins.readFile ./authorized_keys));
          system.stateVersion = "25.11";
        }
        spoons-flakes.nixosModules.nixos-base
      ];
    };
    apps.${system}.test =
    let
      drv = pkgs.writeShellApplication {
        name = "test";
        runtimeInputs = [ ];
        text = ''
          # shellcheck source=/dev/null
          source ${garnix-actions.lib.${system}.withCIEnvironment}
          echo hello
          echo "$GARNIX_COMMIT_SHA $GARNIX_BRANCH"
          echo "${self.packages.${system}.nixos-base}"
        '';
      };
    in {
      type = "app";
      program = "${drv}/bin/${drv.name}";
    };
  };
}

# vim: set ts=2 sw=2 et sta:
