{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ziit;
in {
  options.services.ziit = {
    enable = lib.mkEnableOption "Ziit code time tracking service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ziit;
      defaultText = "pkgs.ziit";
      description = "The Ziit package to use";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ziit";
      description = "User to run Ziit as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ziit";
      description = "Group to run Ziit as";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/ziit";
      description = "The directory where Ziit stores its data";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the specified port in the firewall";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "The host address to bind the server to";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port to run Ziit on";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "The base URL of the Ziit instance (e.g., https://ziit.example.com)";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create the PostgreSQL database locally";
      };

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PostgreSQL database URL (required if createLocally is false)";
      };

      urlFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the PostgreSQL database URL";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "/run/postgresql";
        description = "The host of the PostgreSQL database (use socket path for local)";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "The port of the PostgreSQL database";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "ziit";
        description = "The name of the database";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "ziit";
        description = "The database user";
      };
    };

    pasetoKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "PASETO key for authentication. Generate with: echo k4.local.$(openssl rand -base64 32)";
    };

    pasetoKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the PASETO key";
    };

    adminKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Admin key for the admin dashboard. Generate with: openssl rand -base64 64";
    };

    adminKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the admin key";
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to disable user registration";
    };

    github = {
      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GitHub OAuth client ID";
      };

      clientIdFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the GitHub OAuth client ID";
      };

      clientSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GitHub OAuth client secret";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the GitHub OAuth client secret";
      };
    };

    epilogue = {
      appId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Epilogue OAuth application ID";
      };

      appIdFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Epilogue OAuth application ID";
      };

      appSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Epilogue OAuth application secret";
      };

      appSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Epilogue OAuth application secret";
      };
    };

    environment = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional environment variables to pass to the service";
      example = ["NODE_ENV=production"];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.pasetoKey == null || cfg.pasetoKeyFile == null;
        message = "Cannot set both services.ziit.pasetoKey and services.ziit.pasetoKeyFile";
      }
      {
        assertion = cfg.pasetoKey != null || cfg.pasetoKeyFile != null;
        message = "Must set either services.ziit.pasetoKey or services.ziit.pasetoKeyFile";
      }
      {
        assertion = cfg.adminKey == null || cfg.adminKeyFile == null;
        message = "Cannot set both services.ziit.adminKey and services.ziit.adminKeyFile";
      }
      {
        assertion = cfg.adminKey != null || cfg.adminKeyFile != null;
        message = "Must set either services.ziit.adminKey or services.ziit.adminKeyFile";
      }
      {
        assertion = cfg.database.url == null || cfg.database.urlFile == null;
        message = "Cannot set both services.ziit.database.url and services.ziit.database.urlFile";
      }
      {
        assertion = cfg.database.createLocally || cfg.database.url != null || cfg.database.urlFile != null;
        message = "Must set either services.ziit.database.createLocally or provide a database URL";
      }
      {
        assertion = cfg.github.clientId == null || cfg.github.clientIdFile == null;
        message = "Cannot set both services.ziit.github.clientId and services.ziit.github.clientIdFile";
      }
      {
        assertion = cfg.github.clientSecret == null || cfg.github.clientSecretFile == null;
        message = "Cannot set both services.ziit.github.clientSecret and services.ziit.github.clientSecretFile";
      }
      {
        assertion = cfg.epilogue.appId == null || cfg.epilogue.appIdFile == null;
        message = "Cannot set both services.ziit.epilogue.appId and services.ziit.epilogue.appIdFile";
      }
      {
        assertion = cfg.epilogue.appSecret == null || cfg.epilogue.appSecretFile == null;
        message = "Cannot set both services.ziit.epilogue.appSecret and services.ziit.epilogue.appSecretFile";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
      extensions = exts: with exts; [timescaledb];
      settings.shared_preload_libraries = "timescaledb";
    };

    systemd.tmpfiles.settings."10-ziit" = {
      "${cfg.dataDir}".d = {
        user = cfg.user;
        group = cfg.group;
        mode = "0750";
      };
    };

    systemd.services.ziit = {
      description = "Ziit code time tracking service";
      after = ["network-online.target"] ++ lib.optionals cfg.database.createLocally ["postgresql.service"];
      wants = ["network-online.target"];
      requires = lib.optionals cfg.database.createLocally ["postgresql.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/ziit";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        StateDirectory = "ziit";
        WorkingDirectory = cfg.dataDir;
        Environment =
          [
            "HOST=${cfg.host}"
            "PORT=${toString cfg.port}"
            "NUXT_BASE_URL=${cfg.baseUrl}"
            "NUXT_DISABLE_REGISTRATION=${lib.boolToString cfg.disableRegistration}"
          ]
          ++ (
            if cfg.database.createLocally
            then ["NUXT_DATABASE_URL=postgresql://${cfg.database.user}@${cfg.database.host}/${cfg.database.name}"]
            else lib.optional (cfg.database.url != null) "NUXT_DATABASE_URL=${cfg.database.url}"
          )
          ++ lib.optional (cfg.pasetoKey != null) "NUXT_PASETO_KEY=${cfg.pasetoKey}"
          ++ lib.optional (cfg.adminKey != null) "NUXT_ADMIN_KEY=${cfg.adminKey}"
          ++ lib.optional (cfg.github.clientId != null) "NUXT_GITHUB_CLIENT_ID=${cfg.github.clientId}"
          ++ lib.optional (cfg.github.clientSecret != null) "NUXT_GITHUB_CLIENT_SECRET=${cfg.github.clientSecret}"
          ++ lib.optional (cfg.epilogue.appId != null) "NUXT_EPILOGUE_APP_ID=${cfg.epilogue.appId}"
          ++ lib.optional (cfg.epilogue.appSecret != null) "NUXT_EPILOGUE_APP_SECRET=${cfg.epilogue.appSecret}"
          ++ cfg.environment;
        LoadCredential =
          lib.optional (cfg.pasetoKeyFile != null) "NUXT_PASETO_KEY:${cfg.pasetoKeyFile}"
          ++ lib.optional (cfg.adminKeyFile != null) "NUXT_ADMIN_KEY:${cfg.adminKeyFile}"
          ++ lib.optional (cfg.database.urlFile != null) "NUXT_DATABASE_URL:${cfg.database.urlFile}"
          ++ lib.optional (cfg.github.clientIdFile != null) "NUXT_GITHUB_CLIENT_ID:${cfg.github.clientIdFile}"
          ++ lib.optional (cfg.github.clientSecretFile != null) "NUXT_GITHUB_CLIENT_SECRET:${cfg.github.clientSecretFile}"
          ++ lib.optional (cfg.epilogue.appIdFile != null) "NUXT_EPILOGUE_APP_ID:${cfg.epilogue.appIdFile}"
          ++ lib.optional (cfg.epilogue.appSecretFile != null) "NUXT_EPILOGUE_APP_SECRET:${cfg.epilogue.appSecretFile}";
      };
    };

    users.users = lib.mkIf (cfg.user == "ziit") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
      };
    };

    users.groups = lib.mkIf (cfg.group == "ziit") {
      ${cfg.group} = {};
    };
  };
}
