{ config, lib, pkgs, ... }:
let
  cfg = config.master-software.reverse-proxy;
  reverse_proxy = backend: ''
    reverse_proxy ${backend.matcher} {
      to ${backend.upstream}
    }
  '';
  reverse_proxies = service: builtins.concatStringsSep "\n" (map (backend: ''
    ${reverse_proxy backend}
  '') service.backends);
  site = service: ''
    ${service.domain} {
      header -Server

      ${reverse_proxies service}
    }
  '';
  sites = builtins.concatStringsSep "\n" (map (service: ''
    ${site service}
  '') cfg.services);
  caddyfile = pkgs.writeTextFile {
    name = "Caddyfile";
    text = ''
      ${sites}
    '';
  };
in {
  config = {
    services.docker-compose = {
      enable = true;
      projects = {
        reverse-proxy = {
          content = {
            name = "reverse-proxy";
            services = {
              caddy = {
                init = true;
                image = "caddy:2.8-alpine";
                network_mode = "host";
                volumes = [
                  "/var/lib/reverse-proxy/Caddyfile:/etc/caddy/Caddyfile"
                ];
              };
            };
          };
        };
      };
    };

    systemd.tmpfiles.rules = [
      "L+ /var/lib/reverse-proxy/Caddyfile 0755 root root - ${caddyfile}"
    ];
  };
}