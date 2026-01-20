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
    nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
      inherit pkgs;
      modules = [
        {
          spoons.nixos-image.authorizedKeys = (pkgs.lib.splitString "\n" (builtins.readFile ./authorized_keys));
          system.stateVersion = "25.11";
        }
        spoons-flakes.nixosModules.nixos-base
        nixos-generators.nixosModules.qcow-efi
      ];
    };

    packages.${system}.nixos-base = self.outputs.nixosConfigurations.nixos-base.config.system.build.qcow-efi;

#    packages.${system}.nixos-base = nixos-generators.nixosGenerate {
#      #system = "x86_64-linux";
#      inherit system;
#      format = "qcow-efi";
#      modules = [
#        {
#          spoons.nixos-image.authorizedKeys = (pkgs.lib.splitString "\n" (builtins.readFile ./authorized_keys));
#          system.stateVersion = "25.11";
#        }
#        spoons-flakes.nixosModules.nixos-base
#      ];
#    };

    apps.${system} = {
      setup = garnix-actions.lib.${system}.getGitHubPAT {
        appName = "setup";
        appDescription = "foo";
        actionName = "storeImageURL";
        encryptedTokenFile = "image_url_push_token";
      };

      storeImageURL = 
      let
        drv = pkgs.writeShellApplication (
        let
          encryptedTokenFile = ./image_url_push_token;
        in {
          name = "storeImageURL";
          runtimeInputs = with pkgs; [
            curl
            gawk
            gitMinimal
            age
            gnused
          ];
          text = ''
            # shellcheck source=/dev/null
            source ${garnix-actions.lib.${system}.withCIEnvironment}
            echo hello
            echo "$GARNIX_COMMIT_SHA $GARNIX_BRANCH"
            hash=$(echo "${self.packages.${system}.nixos-base}" | sed -e 's|/nix/store/||' -e 's/-.*$//')
            echo "hash is $hash"
            retries=0
            while true; do
              url=$(curl -s "https://cache.garnix.io/''${hash}.narinfo" | grep ^URL: | awk '{print $2}')
              [ -n "$url" ] && break
              echo -n "Waiting for cache to catch-up "
              retries=$(($retries+1))
              sleep 10
              [ $retries -ge 12 ] && exit 1
              echo -n ". "
            done
            echo
            echo "url is $url"
            if [ -e .secrets ]; then
              echo "using local github secrets"
              GITHUB_API_TOKEN="$(cat ./.secrets)"
            else
              GITHUB_API_TOKEN=$(age --decrypt --identity "$GARNIX_ACTION_PRIVATE_KEY_FILE" ${encryptedTokenFile})
            fi
            if [ -z "$GITHUB_API_TOKEN" ]; then
              echo "no github token, aborting here!"
              exit 1
            fi
            gitdir=$(mktemp -d)

            git config --global user.email "core-admin@ext-mail.spoons.technology"
            git config --global user.name "VM image update action"

            git clone "https://srd424:$GITHUB_API_TOKEN@github.com/spoonstech/vm-image-data" "$gitdir"
            mkdir -p "$gitdir/nixos-base"
            echo "$url" >"$gitdir/nixos-base/url"
            _g () { git -C "$gitdir" "$@"; }
#            git -C "$gitdir" add -A
            _g add -A
#            git -C "$gitdir" commit -m "Updated by garnix CI"
            _g commit -m "Updated by garnix CI"
#            git push
            _g push
            rm -r -f "$gitdir"
          '';
        });
      in {
        type = "app";
        program = "${drv}/bin/${drv.name}";
      };
    };
  };
}

# vim: set ts=2 sw=2 et sta:
