{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config."rust-env".bevy;
in
{
  options."rust-env".bevy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shared Bevy runtime and build dependencies.";
    };

    runtimeLibs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      default = [
        pkgs.alsa-lib
        pkgs.libudev-zero
        pkgs.libxkbcommon
        pkgs.libx11
        pkgs.libxcursor
        pkgs.libxi
        pkgs.libxrandr
        pkgs.mesa
        pkgs.vulkan-loader
        pkgs.wayland
      ];
      description = "Shared Bevy runtime libraries for shell and package builds.";
    };

    nativeBuildInputs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      default = [ pkgs.pkg-config ];
      description = "Native build inputs typically needed for Bevy package builds.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      default = [ pkgs.udev ];
      description = "Extra shell packages commonly needed alongside the Bevy runtime libraries.";
    };
  };

  config = lib.mkIf cfg.enable {
    env.LD_LIBRARY_PATH = lib.concatStringsSep ":" [
      (lib.makeLibraryPath cfg.runtimeLibs)
      "/run/opengl-driver/lib"
    ];

    packages = cfg.runtimeLibs ++ cfg.nativeBuildInputs ++ cfg.extraPackages;
  };
}
