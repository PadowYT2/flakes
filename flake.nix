{
  description = "Modules and packages of different software";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs:
    {
      nixosModules.default = {
        imports = [
          ./sure/module.nix
          ./ziit/module.nix
        ];
      };

      overlays.default = final: prev: {
        sure = prev.callPackage ./sure/default.nix {};
        ziit = prev.callPackage ./ziit/default.nix {};
      };
    }
    // (inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      packages = {
        sure = pkgs.sure;
        ziit = pkgs.ziit;
      };
    }));
}
