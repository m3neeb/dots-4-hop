{ config, lib, ... }:

{
  programs.mpv = {
    enable = true;

    defaultProfiles = [ "high-quality" ];

    config = {
      glsl-shaders = ''"~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"'';
      title-bar = "no";
      osc = "no";
      autofit = "95%";
      save-position-on-quit = "yes";
      volume = "50";
      demuxer-mkv-subtitle-preroll = "yes";
      dither-depth = "auto";
      scale = "spline36";
      dscale = "mitchell";
      cscale = "mitchell";
      screenshot-format = "png";
      screenshot-high-bit-depth = "yes";
      screenshot-png-compression = "1";
      screenshot-dir = ''"~/Pictures/Screenshots"'';
      vo = "gpu-next";
      gpu-api = "vulkan";
      keep-open = "yes";
    };

    bindings = {
      "CTRL+1" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A (Fast)"'';
      "CTRL+2" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode B (Fast)"'';
      "CTRL+3" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode C (Fast)"'';
      "CTRL+4" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_Restore_CNN_S.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A+A (Fast)"'';
      "CTRL+5" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode B+B (Fast)"'';
      "CTRL+6" = ''no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Restore_CNN_S.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode C+A (Fast)"'';
      "CTRL+0" = ''no-osd change-list glsl-shaders clr ""; show-text "GLSL shaders cleared"'';
    };

    scriptOpts = {
      thumbfast = {
        socket = "";
        thumbnail = "";
        max_height = "200";
        max_width = "200";
        scale_factor = "1";
        tone_mapping = "auto";
        overlay_id = "42";
        spawn_first = "no";
        quit_after_inactivity = "0";
        network = "no";
        audio = "no";
        hwdec = "no";
        direct_io = "no";
        mpv_path = "mpv";
      };
      material-osc = {
        dpi_scale = "auto";
        accent_color = ''"#00fa9a"'';
        context_menu = "yes";
        tooltip = "yes";
        show_mini_seekbar = "no";
        screenshot_button = "yes";
        pip_button = "yes";
        window_controls = "no";
        mouse_timeout = "2";
        show_on_mouse_move = "no";
        single_click_actions_enabled = "yes";
        seeking_zone_percentage = "15";
        seek_step_seconds = "5";
        temporary_speed = "2";
        max_volume_percentage = "150";
        skip_intro_outro_chapters = "ask";
        skip_intro_detection_texts = "intro,introduction,opening,op,opening theme";
        skip_outro_detection_texts = "outro,ending,end credits,credits,closing,ed";
        force_hwdec = "no";
        force_display_resample = "yes";
        force_force_window = "yes";
        directory_playlist = "yes";
        directory_playlist_sort = "name";
        youtube_quality = "auto";
        sponsorblock_should_use = "yes";
        sponsorblock_auto_skip_categories = "sponsor";
        sponsorblock_ignore_categories = "interaction,preview,hook,exclusive_access";
        sponsorblock_multicolored_segments = "yes";
        sponsorblock_show_submit = "yes";
        sponsorblock_show_voting = "yes";
        show_empty_screen = "yes";
        show_remaining_time = "no";
        adjust_time_with_speed = "yes";
        adjust_subtitle_position = "yes";
      };
    };
  };

  # material-osc.lua self-updates and writes its own state, so it can't be a
  # read-only symlink: seed once from the repo, never overwrite
  home.activation.seedMpvFiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    src=${./config/mpv-seed}
    dst="${config.xdg.configHome}/mpv"
    for f in scripts/material-osc.lua scripts/thumbfast.lua \
             fonts/material-osc_google_sans_flex.ttf fonts/material-osc_icons.otf; do
      if [ ! -e "$dst/$f" ]; then
        run install -D -m 0644 "$src/$f" "$dst/$f"
      fi
    done
  '';
}
