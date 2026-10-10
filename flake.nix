{
  description = "great-machine-rails: a Rails application to roll out with great-machine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems }:
    let
      eachSystem = f:
        nixpkgs.lib.genAttrs (import systems)
        (system: f system nixpkgs.legacyPackages.${system});

      # The commit a build is made from, for the page to say. A tree with
      # changes that are not committed is named so.
      revision = self.shortRev or self.dirtyShortRev or "unknown";
    in {
      packages = eachSystem (system: pkgs:
        let
          ruby = pkgs.ruby_3_4;

          # Every gem of Gemfile.lock, built by Nix. gemset.nix names each
          # with its hash; `bundix` writes it anew after a change of the
          # Gemfile (see the README). It is built from the three files
          # alone, so a change of the application builds no gem again.
          gems = pkgs.bundlerEnv {
            name = "great-machine-rails-gems";
            inherit ruby;
            gemdir = ./.;
          };

          # The application as Rails wants it laid out, and nothing that is
          # not part of it: a change of this file or of the README makes no
          # new release.
          app = pkgs.stdenvNoCC.mkDerivation {
            pname = "great-machine-rails-app";
            version = revision;
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./app
                ./bin
                ./config
                ./public
                ./config.ru
                ./Rakefile
                ./Gemfile
                ./Gemfile.lock
              ];
            };
            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
            installPhase = ''
              mkdir -p $out
              cp -r . $out/
              echo ${revision} > $out/REVISION
            '';
          };

          # What great-machine is given: one file to start, whose closure
          # is everything the application needs (Ruby, the gems, the
          # application and this shell). zathras starts it with the
          # environment of the app container and whatever directory it is
          # in, so the file sets what Rails needs itself, and leaves alone
          # what the container has set.
          great-machine-rails = pkgs.writeShellScriptBin "great-machine-rails" ''
            set -eu
            export RAILS_ENV="''${RAILS_ENV:-production}"
            # The Service of the pods sends to this port.
            export PORT="''${PORT:-8080}"
            # The image has no locale; Ruby would read files as US-ASCII.
            export LANG="''${LANG:-C.UTF-8}"
            cd ${app}
            exec ${gems}/bin/puma --config config/puma.rb
          '';
        in {
          default = great-machine-rails;
          inherit app gems;
        });

      # The shell has Ruby with the gems, so `bin/rails server` and
      # `bin/rails console` work in it, and the built application: on a
      # Linux machine `great-machine rollout demo "$(command -v
      # great-machine-rails)"` rolls out what the tree holds. direnv
      # reloads the shell, and so builds anew, when the application changes
      # (see .envrc).
      devShells = eachSystem (system: pkgs:
        let p = self.packages.${system};
        in {
          default = pkgs.mkShell {
            packages = [ p.gems p.gems.wrappedRuby pkgs.bundix p.default ];
          };
        });
    };
}
