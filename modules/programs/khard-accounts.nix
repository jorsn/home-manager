{ config, lib, ... }:

with lib;

{
  options.khard = {
    enable = lib.mkEnableOption "khard access";
  };
}
