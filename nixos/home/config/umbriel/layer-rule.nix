{
  layer_rule = [
    {
      match = { namespace = "^noctalia-(window-switcher)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(notification)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(osd)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(bar-[^\"]+)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(bar-Flat)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(panel)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(attached-panel)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
    {
      match = { namespace = "^noctalia-(dock)$"; };
      blur = true;
      blur_popups = false;
      blur_optimized = false;
      blur_ignore_alpha = 0.5;
    }
  ];
}
