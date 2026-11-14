{config, ...}: let
  tunnelId = "405573b8-a776-4e4f-a88c-a9d7683b90de";
in {
  # Contents: tunnel credentials JSON from `cloudflared tunnel create mediabox`
  sops.secrets."cloudflared-creds" = {};

  # Locally managed tunnel "mediabox", separate from the NUC's token tunnel.
  # Add hostnames to `ingress` as services move over. Plex stays out
  # (Cloudflare ToS on video streaming; Plex has its own remote access).
  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = config.sops.secrets."cloudflared-creds".path;
      default = "http_status:404";
      ingress."ssh-mediabox.murfly.me" = "ssh://localhost:22";
      ingress."bw.murfly.me" = "http://127.0.0.1:8222";
      ingress."tm.murfly.me" = "http://127.0.0.1:9091";
    };
  };
}
