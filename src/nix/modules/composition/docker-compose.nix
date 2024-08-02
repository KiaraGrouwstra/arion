/*

   This is a composition-level module.

   It defines the low-level options that are read by arion, like
    - out.dockerComposeYaml

   It declares options like
    - services

 */
compositionArgs@{ lib, config, pkgs, ... }:
let
  inherit (lib) types;

  service = {
    imports = [ argsModule ] ++ import ../service/all-modules.nix;
  };
  argsModule =
    { name, # injected by types.submodule
      ...
    }: {
      _file = ./docker-compose.nix;
      key = ./docker-compose.nix;

      config._module.args.pkgs = lib.mkDefault compositionArgs.pkgs;
      config.host = compositionArgs.config.host;
      config.composition = compositionArgs.config;
      config.service.name = name;
    };

  dockerComposeRef = fragment:
    ''See <link xlink:href="https://docs.docker.com/compose/compose-file/#${fragment}">Docker Compose#${fragment}</link>'';

  secretType = lib.types.submodule {
    options = {
      file = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        description = ''
          Sets the secret's value to this file.

          ${dockerComposeRef "secrets"}
        '';
      };
      external = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the value of this secret is set via other means.

          ${dockerComposeRef "secrets"}
        '';
      };
    };
  };

in
{
  imports = [
    ../lib/assert.nix
    (lib.mkRenamedOptionModule ["docker-compose" "services"] ["services"])
  ];
  options = {
    out.dockerComposeYaml = lib.mkOption {
      type = lib.types.package;
      description = "A derivation that produces a docker-compose.yaml file for this composition.";
      readOnly = true;
    };
    out.dockerComposeYamlText = lib.mkOption {
      type = lib.types.str;
      description = "The text of out.dockerComposeYaml.";
      readOnly = true;
    };
    out.dockerComposeYamlAttrs = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      description = "The text of out.dockerComposeYaml.";
      readOnly = true;
    };
    docker-compose.raw = lib.mkOption {
      type = lib.types.attrs;
      description = "Attribute set that will be turned into the docker-compose.yaml file, using Nix's toJSON builtin.";
    };
    docker-compose.extended = lib.mkOption {
      type = lib.types.attrs;
      description = "Attribute set that will be turned into the x-arion section of the docker-compose.yaml file.";
    };
    services = lib.mkOption {
      type = lib.types.attrsOf (types.submodule service);
      description = "An attribute set of service configurations. A service specifies how to run an image as a container.";
    };
    docker-compose.volumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      description = "A attribute set of volume configurations.";
      default = {};
    };
    docker-compose.secrets = lib.mkOption {
      type = lib.types.attrsOf secretType;
      description = dockerComposeRef "secrets";
      default = {};
    };
  };
  config = {
    out.dockerComposeYaml = pkgs.writeText "docker-compose.yaml" config.out.dockerComposeYamlText;
    out.dockerComposeYamlText = builtins.toJSON (config.out.dockerComposeYamlAttrs);
    out.dockerComposeYamlAttrs = config.assertWarn config.docker-compose.raw;

    docker-compose.raw = {
      version = "3.4";
      services = lib.mapAttrs (k: c: c.out.service) config.services;
      x-arion = config.docker-compose.extended;
      volumes = config.docker-compose.volumes;
    } // lib.optionalAttrs (config.docker-compose.secrets != {}) {
      secrets = lib.mapAttrs (_k: s: lib.optionalAttrs (s.external != false) {
        inherit (s) external;
      } // lib.optionalAttrs (s.file != null) {
        file = toString s.file;
      }
      ) config.docker-compose.secrets;
    };
  };
}
