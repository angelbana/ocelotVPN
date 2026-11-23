{
  description = "Ocelot VPN client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    qt-solutions = {
      url = "github:qtproject/qt-solutions/master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, qt-solutions }:
    {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ocelot = pkgs.stdenv.mkDerivation {
            pname = "ocelot";
            version = "1.1.5";
            src = pkgs.lib.cleanSource self.outPath;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.pkg-config
              pkgs.qt6.wrapQtAppsHook
            ];

            buildInputs = [
              pkgs.gnutls
              pkgs.openconnect
              pkgs.spdlog
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qttools
              pkgs.qt6.qtwayland

              # pkg-config follows the private requirements of both VPN libraries.
              pkgs.libidn2
              pkgs.libtasn1
              pkgs.libxml2
              pkgs.p11-kit
              pkgs.pcsclite
              pkgs.stoken
              pkgs.zlib
            ];

            postPatch = ''
              cp -R ${qt-solutions} external/qt-solutions
              chmod -R u+w external/qt-solutions
              cmakeFlagsArray+=("-DQT_SOLUTIONS_SOURCE_DIR=$PWD/external/qt-solutions")
            '';

            cmakeFlags = [
              "-DVPNC_SCRIPT=${pkgs.vpnc-scripts}/bin/vpnc-script"
            ];

            meta = {
              description = "OpenConnect-based VPN client";
              homepage = "https://github.com/angelbana/ocelotVPN";
              license = pkgs.lib.licenses.gpl2Plus;
              mainProgram = "ocelot";
            };
          };
        in
        {
          inherit ocelot;
          default = ocelot;
        });
    };
}
