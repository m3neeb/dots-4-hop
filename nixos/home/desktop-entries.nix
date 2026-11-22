{ ... }:

let
  webApp = name: url: icon: {
    inherit name icon;
    exec = "xdg-open ${url}";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
  };
  localIcon = file: "/home/aeon/.local/share/icons/${file}";
in
{
  xdg.desktopEntries = {
    chatgpt = webApp "ChatGPT" "https://chat.openai.com/" (localIcon "gpt.png");
    mojza = webApp "Mojza" "https://www.mojza.org/" (localIcon "mojza.png");
    gmail = webApp "Gmail" "https://mail.google.com/" "gmail";
    google-drive = webApp "Google Drive" "https://drive.google.com/drive/home" "google-drive";
    instagram = webApp "Instagram" "https://www.instagram.com/" "instagram";
    whatsapp = webApp "WhatsApp" "https://web.whatsapp.com/" "whatsapp";
    youtube = webApp "YouTube" "https://www.youtube.com" "youtube";

    "dev.noctalia.luciole" = {
      name = "Luciole";
      genericName = "File Manager";
      comment = "Browse and manage files";
      exec = "luciole %F";
      icon = localIcon "dev.noctalia.luciole.png";
      terminal = false;
      categories = [ "System" "FileTools" "FileManager" ];
      mimeType = [ "inode/directory" ];
      startupNotify = true;
      settings.StartupWMClass = "dev.noctalia.luciole";
    };
  };
}
