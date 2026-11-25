{
  general = {
    autostart = [
      "noctalia"
      "dbus-update-activation-environment --all"
      "sh -c 'umbriel subscribe workspaces | while IFS= read -r event; do noctalia msg plugin tordex/stdout:bar all update; done'"
    ];
  };
}
