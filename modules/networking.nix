{
  networking.useDHCP = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
}

