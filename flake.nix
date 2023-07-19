{
  inputs.flakes.url = "github:deemp/flakes";

  outputs =
    inputs:
    let
      inputs_ =
        let flakes = inputs.flakes.flakes; in
        {
          inherit (flakes.source-flake) flake-utils nixpkgs;
          inherit (flakes) drv-tools flakes-tools workflows devshell codium;
          inherit flakes;
        };

      outputs = outputs_ { } // { inputs = inputs_; outputs = outputs_; };

      outputs_ =
        inputs__:
        let inputs = inputs_ // inputs__; in
        inputs.flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          inherit (inputs.codium.lib.${system}) writeSettingsJSON mkCodium;
          inherit (inputs.drv-tools.lib.${system}) mkShellApps mkBin;
          inherit (inputs.flakes-tools.lib.${system}) mkFlakesTools;
          inherit (inputs.codium.lib.${system}) extensions settingsNixCommon extensionsCommon;
          inherit (inputs.devshell.lib.${system}) mkShell mkRunCommands;

          backDir = "back";
          frontDir = "front";
          scripts = mkShellApps {
            back = {
              text = "cd ${backDir} && nix run";
              description = "Run backend";
            };
            front = {
              text = "cd ${frontDir} && nix run";
              description = "Run frontend";
            };
          };

          packages = {
            inherit (mkFlakesTools { dirs = [ "front" "back" "." ]; root = ./.; }) pushToCachix updateLocks;

            writeSettings = writeSettingsJSON settingsNixCommon;
            codium = mkCodium { extensions = extensionsCommon; };

            writeWorkflows = import ./nix-files/workflow.nix {
              name = "ci";
              inherit backDir frontDir system;
              inherit (inputs) workflows;
            };
          } // scripts;

          devShells.default = mkShell {
            commands =
              mkRunCommands "ide" { "codium ." = packages.codium; inherit (packages) writeSettings; }
              ++ mkRunCommands "infra" { inherit (packages) writeWorkflows pushToCachix updateLocks; }
            ;
          };
        in
        {
          inherit packages devShells;
        });
    in
    outputs;

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.iog.io"
      "https://deemp.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "deemp.cachix.org-1:9shDxyR2ANqEPQEEYDL/xIOnoPwxHot21L5fiZnFL18="
    ];
  };
}
