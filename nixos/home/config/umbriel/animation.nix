{
  animation = {
    enabled = true;
    duration_ms = 185;
    curve = "cinematic";
    beziers = {
      cinematic = [ 0.16 0.84 0.24 1.0 ];
      window_flow = [ 0.2 0.75 0.25 1.0 ];
      workspace_flow = [ 0.2 0.8 0.24 1.0 ];
    };
    springs = {
      apparition = { damping = 0.7; stiffness = 240; };
    };
    windows_in = {
      enabled = true;
      curve = "cinematic";
      style = "popin";
      scale = 0.85;
    };
    windows_out = {
      enabled = true;
      duration_ms = 165;
      curve = "easeoutcubic";
      style = "fade";
    };
    windows_move = { enabled = true; duration_ms = 195; curve = "window_flow"; };
    workspaces = { enabled = true; duration_ms = 225; curve = "workspace_flow"; };
    overview = {
      enabled = true;
      duration_ms = 280;
      curve = "cinematic";
      workspace_curve = "workspace_flow";
    };
    scratchpad = {
      enabled = true;
      duration_ms = 215;
      curve = "easeinoutcubic";
      dim = 0.42;
      blur = false;
    };
    border = { enabled = false; duration_ms = 200; curve = "ease"; };
    dim_unfocused = { enabled = false; duration_ms = 200; curve = "ease"; dim = 0.0; };
    layers = { enabled = true; duration_ms = 175; curve = "easeoutcubic"; };
  };
}
