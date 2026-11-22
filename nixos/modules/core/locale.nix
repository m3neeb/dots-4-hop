{ ... }:

{
  time.timeZone = "Asia/Karachi";

  # Every LC_* category was set to the same value as the default locale,
  # so defaultLocale alone covers them.
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
