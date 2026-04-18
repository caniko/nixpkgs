{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkDefault
    mkIf
    mkOption
    types
    ;
  cfg = config.services.surrealdb;

  backendToDbPath =
    backend:
    if backend == "rocksdb" then
      "rocksdb:///var/lib/surrealdb/"
    else if backend == "memory" then
      "memory"
    else
      "surrealkv:///var/lib/surrealdb/";

  defaultPackage = if cfg.backend == "rocksdb" then pkgs.surrealdb-rocksdb else pkgs.surrealdb;

  effectiveDbPath = if cfg.dbPath != null then cfg.dbPath else backendToDbPath cfg.backend;
in
{

  options = {
    services.surrealdb = {
      enable = lib.mkEnableOption "SurrealDB, a scalable, distributed, collaborative, document-graph database, for the realtime web";

      package = lib.mkPackageOption pkgs "surrealdb" { };

      backend = mkOption {
        type = types.enum [
          "surrealkv"
          "rocksdb"
          "memory"
        ];
        default = "surrealkv";
        description = ''
          Storage backend to use when `dbPath` is not set. `surrealkv` is the
          default, `rocksdb` switches to the RocksDB-enabled package variant,
          and `memory` runs without on-disk persistence.
        '';
      };

      dbPath = mkOption {
        type = types.nullOr types.str;
        description = ''
          Raw datastore URI passed to `surreal start`. If unset, derive it from
          `backend`. The packaged defaults cover `surrealkv:///...`,
          `rocksdb:///...`, and `memory`; other URI schemes require a custom
          `package` that enables the corresponding backend.
        '';
        default = null;
        defaultText = literalExpression ''
          if config.services.surrealdb.backend == "rocksdb"
          then "rocksdb:///var/lib/surrealdb/"
          else if config.services.surrealdb.backend == "memory"
          then "memory"
          else "surrealkv:///var/lib/surrealdb/"
        '';
        example = "memory";
      };

      host = mkOption {
        type = types.str;
        description = ''
          The host that surrealdb will connect to.
        '';
        default = "127.0.0.1";
        example = "127.0.0.1";
      };

      port = mkOption {
        type = types.port;
        description = ''
          The port that surrealdb will connect to.
        '';
        default = 8000;
        example = 8000;
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "--allow-all"
          "--user"
          "root"
          "--pass"
          "root"
        ];
        description = ''
          Specify a list of additional command line flags.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.surrealdb.package = mkDefault defaultPackage;

    # Used to connect to the running service
    environment.systemPackages = [ cfg.package ];

    systemd.services.surrealdb = {
      description = "A scalable, distributed, collaborative, document-graph database, for the realtime web";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/surreal start --bind ${cfg.host}:${toString cfg.port} ${lib.strings.concatStringsSep " " cfg.extraFlags} -- ${effectiveDbPath}";
        DynamicUser = true;
        Restart = "on-failure";
        StateDirectory = "surrealdb";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectClock = true;
        ProtectProc = "noaccess";
        ProcSubset = "pid";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RemoveIPC = true;
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };
  };
}
