{ lib, pkgs, config, modulesPath, ... }:
with lib;
let
  cfg = config.modules.system;
in {
  options.modules.system = {
    stateVersion = mkOption {
      type = types.str;
    };

    timeZone = mkOption {
      type = types.str;
      default = "UTC";
    };

    hostName = mkOption {
      type = types.str;
    };

    sshPort = mkOption {
      type = types.int;
    };

    sshAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [];
    };

    userName = mkOption {
      type = types.str;
      default = "nixos";
    };

    allowedTCPPorts = mkOption {
      type = types.listOf types.int;
      default = [ ];
    };

    useDocker = mkOption {
      type = types.bool;
      default = false;
    };
  };

  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  config = {
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";

    time.timeZone = cfg.timeZone;
    system.stateVersion = cfg.stateVersion;

    networking = {
      hostName = cfg.hostName;
      networkmanager.enable = true;

      firewall = {
        enable = true;
        allowedTCPPorts = [ cfg.sshPort ] ++ cfg.allowedTCPPorts;
      };
    };

    users.users = {
      "${cfg.userName}" = {
        isNormalUser = true;
        extraGroups = [ "wheel" ] ++ (if cfg.useDocker then [ "docker" ] else [ ]);
        packages = with pkgs; [ ];
        openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;
      };
    };

    virtualisation.docker = mkIf cfg.useDocker {
      enable = true;
      enableOnBoot = true;
      autoPrune.enable = true;
    };

    services.openssh = {
      enable = true;
      ports = [ cfg.sshPort ];
      openFirewall = false;
      settings = {
        X11Forwarding = false;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    security.pam = {
      sshAgentAuth = {
        enable = true;
        authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
      };
    };

    # Hardware configuration

    boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    swapDevices = [
      { device = "/dev/disk/by-label/swap"; }
    ];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault true;
    # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
