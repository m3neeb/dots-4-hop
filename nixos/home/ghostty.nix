{ ... }:

{
  # themes/noctalia is Noctalia's, not declared here; `theme = noctalia` just points at it
  programs.ghostty = {
    enable = true;

    # Ghostty injects its own fish integration
    enableFishIntegration = false;

    settings = {
      font-family = "Iosevka Nerd Font Propo";
      font-size = "12";
      command = "/run/current-system/sw/bin/fish";
      theme = "noctalia";
      background-opacity = "1.0";
      window-decoration = false;
      window-padding-x = "25";
      window-padding-y = "20";
      window-padding-balance = true;
      window-padding-color = "extend";
      window-width = "90";
      window-height = "30";
      window-save-state = "never";
      window-step-resize = false;
      cursor-style = "block";
      cursor-style-blink = true;
      custom-shader = "~/.config/ghostty/shaders/cursor_wrap.glsl";
      custom-shader-animation = "always";
      copy-on-select = "clipboard";
      scrollback-limit = "200000";
      scrollbar = "never";
      link-url = true;
      link-previews = false;
      mouse-hide-while-typing = true;
      app-notifications = "no-clipboard-copy, no-config-reload";
      confirm-close-surface = false;
      quit-after-last-window-closed = false;
    };
  };

  xdg.configFile."ghostty/shaders".source = ./config/ghostty/shaders;
}
