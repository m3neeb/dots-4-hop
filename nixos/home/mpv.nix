{ ... }:

{
  # recursive: per-file links, so mpv and its scripts can still write beside them.
  xdg.configFile."mpv" = {
    source = ./config/mpv;
    recursive = true;
  };
}
