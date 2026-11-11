{...}: {
  sops.defaultSopsFile = ../../secrets/mediabox.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # Contents: WIFI_SSID=... and WIFI_PSK=... (env-file format)
  sops.secrets."wifi-env" = {};
}
