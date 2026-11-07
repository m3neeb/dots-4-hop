{ pkgs, ...}:

{
  environment.systemPackages = with pkgs; [
    (gearlever.overrideAttrs (old: {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (pkgs.lib.makeBinPath (with pkgs; [
          file
          _7zz
          which
          appimage-run
          desktop-file-utils
          gtk4.dev
          bintools
          libnotify
          dwarfs
          squashfs-tools
        ]))
      ];

      preFixup = (old.preFixup or "") + ''
        makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
      '';
    }))
  ];
}
