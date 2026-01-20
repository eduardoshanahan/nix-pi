{ config, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowAgentForwarding = "yes";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys/%u";
    };
  };

  users.allowNoPasswordLogin = true;

  systemd.tmpfiles.rules = [
    "d /etc/ssh/authorized_keys 0755 root root -"
  ];
}
