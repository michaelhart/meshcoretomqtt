{self, ...}: {
  imports = [
  ];
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    # Development shell
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        (python313.withPackages (ps:
          with ps; [
            paho-mqtt
            pyserial
          ]))
        self'.packages.meshcore-decoder
      ];
    };
  };
}
