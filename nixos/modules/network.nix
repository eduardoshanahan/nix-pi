{ config, ... }:
{
  networking.useDHCP = true;
  networking.domain = config.lab.domain;
  networking.wireless.enable = false;
}
