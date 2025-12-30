{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sure;

  env =
    (lib.filterAttrs (n: v: v != null) {
      RAILS_ENV = "production";
      SELF_HOSTED = true;
      ONBOARDING_STATE = cfg.onboardingState;

      SECRET_KEY_BASE =
        if cfg.secretKeyBaseFile != null
        then "@SECRET_KEY_BASE@"
        else cfg.secretKeyBase;

      DB_HOST =
        if cfg.database.createLocally
        then "/run/postgresql"
        else cfg.database.host;
      DB_PORT = cfg.database.port;
      POSTGRES_DB = cfg.database.name;
      POSTGRES_USER = cfg.database.user;
      POSTGRES_PASSWORD =
        if cfg.database.passwordFile != null
        then "@POSTGRES_PASSWORD@"
        else cfg.database.password;

      REDIS_URL =
        if cfg.redis.createLocally
        then "unix://${config.services.redis.servers."${toString cfg.redis.name}".unixSocket}?db=${toString cfg.redis.name}"
        else "redis://${cfg.redis.host}:${toString cfg.redis.port}/${toString cfg.redis.name}";

      PORT = cfg.port;
      APP_DOMAIN = cfg.appDomain;
      PRODUCT_NAME = cfg.productName;
      BRAND_NAME = cfg.brandName;

      EXCHANGE_RATE_PROVIDER = cfg.exchangeRateProvider;
      SECURITIES_PROVIDER = cfg.securitiesProvider;
      TWELVE_DATA_API_KEY =
        if cfg.twelveData.apiKeyFile != null
        then "@TWELVE_DATA_API_KEY@"
        else cfg.twelveData.apiKey;

      OPENAI_ACCESS_TOKEN =
        if cfg.openai.accessTokenFile != null
        then "@OPENAI_ACCESS_TOKEN@"
        else cfg.openai.accessToken;
      OPENAI_MODEL = cfg.openai.model;
      OPENAI_URI_BASE = cfg.openai.uriBase;

      LANGFUSE_HOST = cfg.langfuse.host;
      LANGFUSE_PUBLIC_KEY = cfg.langfuse.publicKey;
      LANGFUSE_SECRET_KEY =
        if cfg.langfuse.secretKeyFile != null
        then "@LANGFUSE_SECRET_KEY@"
        else cfg.langfuse.secretKey;

      SMTP_ADDRESS = cfg.smtp.address;
      SMTP_PORT = cfg.smtp.port;
      SMTP_USERNAME = cfg.smtp.username;
      SMTP_PASSWORD =
        if cfg.smtp.passwordFile != null
        then "@SMTP_PASSWORD@"
        else cfg.smtp.password;
      SMTP_TLS_ENABLED = cfg.smtp.tlsEnabled;
      EMAIL_SENDER = cfg.smtp.emailSender;

      OIDC_CLIENT_ID = cfg.oidc.clientId;
      OIDC_CLIENT_SECRET =
        if cfg.oidc.clientSecretFile != null
        then "@OIDC_CLIENT_SECRET@"
        else cfg.oidc.clientSecret;
      OIDC_ISSUER = cfg.oidc.issuer;
      OIDC_REDIRECT_URI = cfg.oidc.redirectUri;
    })
    // cfg.extraEnvironment;

  setupScript = pkgs.writeShellApplication {
    name = "sure-setup";
    runtimeInputs = with pkgs; [coreutils replace-secret];
    text = ''
      install -Dm640 -o ${cfg.user} -g ${cfg.group} ${pkgs.writeText "sure.env" (lib.generators.toKeyValue {
          mkKeyValue = lib.generators.mkKeyValueDefault {
            mkValueString = v:
              if builtins.isString v && lib.strings.hasInfix " " v
              then ''"${v}"''
              else lib.generators.mkValueStringDefault {} v;
          } "=";
        }
        env)} ${cfg.dataDir}/.env

      ${lib.optionalString (cfg.secretKeyBaseFile != null) ''
        replace-secret '@SECRET_KEY_BASE@' ${lib.escapeShellArg cfg.secretKeyBaseFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.database.passwordFile != null) ''
        replace-secret '@POSTGRES_PASSWORD@' ${lib.escapeShellArg cfg.database.passwordFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.twelveData.apiKeyFile != null) ''
        replace-secret '@TWELVE_DATA_API_KEY@' ${lib.escapeShellArg cfg.twelveData.apiKeyFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.openai.accessTokenFile != null) ''
        replace-secret '@OPENAI_ACCESS_TOKEN@' ${lib.escapeShellArg cfg.openai.accessTokenFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.langfuse.secretKeyFile != null) ''
        replace-secret '@LANGFUSE_SECRET_KEY@' ${lib.escapeShellArg cfg.langfuse.secretKeyFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.smtp.passwordFile != null) ''
        replace-secret '@SMTP_PASSWORD@' ${lib.escapeShellArg cfg.smtp.passwordFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.oidc.clientSecretFile != null) ''
        replace-secret '@OIDC_CLIENT_SECRET@' ${lib.escapeShellArg cfg.oidc.clientSecretFile} ${cfg.dataDir}/.env
      ''}

      ${lib.optionalString (cfg.extraEnvironmentFile != null) ''
        cat ${lib.escapeShellArg cfg.extraEnvironmentFile} >> ${cfg.dataDir}/.env
      ''}

      set -a
      # shellcheck disable=SC1091
      source ${cfg.dataDir}/.env
      set +a

      ${cfg.package}/bin/sure-rails db:migrate
    '';
  };

  cfgService = {
    User = cfg.user;
    Group = cfg.group;
    WorkingDirectory = cfg.package;
    StateDirectory = "sure";
    ReadWritePaths = [cfg.dataDir];
    EnvironmentFile = "${cfg.dataDir}/.env";
  };
in {
  options.services.sure = {
    enable = lib.mkEnableOption "Sure personal finance app";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sure;
      defaultText = "pkgs.sure";
      description = "The Sure package to use";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sure";
      description = "User to run Sure as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sure";
      description = "Group to run Sure as";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sure";
      description = "The root directory where all of Sure's data is stored";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "The interface that Sure should bind to";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "The port that Sure should bind to";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the Sure port in the firewall";
    };

    onboardingState = lib.mkOption {
      type = lib.types.enum ["open" "closed" "invite_only"];
      default = "open";
      description = "The onboarding state for new users";
    };

    secretKeyBase = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Rails secret key base";
    };

    secretKeyBaseFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the Rails secret key base";
    };

    appDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The domain where Sure is hosted";
    };

    productName = lib.mkOption {
      type = lib.types.str;
      default = "Sure";
      description = "The product name";
    };

    brandName = lib.mkOption {
      type = lib.types.str;
      default = "FOSS";
      description = "The brand name";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create the database locally";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "The host of the database";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "The port of the database";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "sure";
        description = "The name of the database";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "sure";
        description = "The user for the database";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The password for the database";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the database password";
      };
    };

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create the Redis instance locally";
      };

      name = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "The name of the Redis server to create";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "The host of the Redis server";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "The port of the Redis server";
      };
    };

    exchangeRateProvider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["twelve_data" "yahoo_finance"]);
      default = "twelve_data";
      description = "The exchange rate provider to use";
    };

    securitiesProvider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["twelve_data" "yahoo_finance"]);
      default = "twelve_data";
      description = "The securities provider to use";
    };

    twelveData = {
      apiKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TwelveData API key";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the TwelveData API key";
      };
    };

    openai = {
      accessToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OpenAI access token";
      };

      accessTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the OpenAI access token";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OpenAI model to use";
      };

      uriBase = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OpenAI base URI";
      };
    };

    langfuse = {
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "https://cloud.langfuse.com";
        description = "Langfuse host URL";
      };

      publicKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Langfuse public key";
      };

      secretKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Langfuse secret key";
      };

      secretKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the Langfuse secret key";
      };
    };

    smtp = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The host of the SMTP server";
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "The port of the SMTP server";
      };

      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The username for the SMTP server";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The password for the SMTP server";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the SMTP password";
      };

      tlsEnabled = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to enable TLS for SMTP";
      };

      emailSender = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The email sender address";
      };
    };

    oidc = {
      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OIDC client ID";
      };

      clientSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OIDC client secret";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the OIDC client secret";
      };

      issuer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OIDC issuer URL";
      };

      redirectUri = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OIDC redirect URI";
      };
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables to be merged with the main environment variables";
    };

    extraEnvironmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Additional environment file to be merged with other environment variables";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.secretKeyBase == null || cfg.secretKeyBaseFile == null;
        message = "cannot set both services.sure.secretKeyBase and services.sure.secretKeyBaseFile";
      }
      {
        assertion = cfg.secretKeyBase != null || cfg.secretKeyBaseFile != null;
        message = "must set either services.sure.secretKeyBase or services.sure.secretKeyBaseFile";
      }
      {
        assertion = cfg.database.password == null || cfg.database.passwordFile == null;
        message = "cannot set both services.sure.database.password and services.sure.database.passwordFile";
      }
      {
        assertion = cfg.twelveData.apiKey == null || cfg.twelveData.apiKeyFile == null;
        message = "cannot set both services.sure.twelveData.apiKey and services.sure.twelveData.apiKeyFile";
      }
      {
        assertion = cfg.openai.accessToken == null || cfg.openai.accessTokenFile == null;
        message = "cannot set both services.sure.openai.accessToken and services.sure.openai.accessTokenFile";
      }
      {
        assertion = cfg.langfuse.secretKey == null || cfg.langfuse.secretKeyFile == null;
        message = "cannot set both services.sure.langfuse.secretKey and services.sure.langfuse.secretKeyFile";
      }
      {
        assertion = cfg.smtp.password == null || cfg.smtp.passwordFile == null;
        message = "cannot set both services.sure.smtp.password and services.sure.smtp.passwordFile";
      }
      {
        assertion = cfg.oidc.clientSecret == null || cfg.oidc.clientSecretFile == null;
        message = "cannot set both services.sure.oidc.clientSecret and services.sure.oidc.clientSecretFile";
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
    };

    services.redis.servers."${toString cfg.redis.name}" = lib.mkIf cfg.redis.createLocally {
      enable = true;
      user = cfg.user;
      group = cfg.group;
    };

    systemd.tmpfiles.settings."10-sure" =
      lib.attrsets.genAttrs
      [
        "${cfg.dataDir}/storage"
        "${cfg.dataDir}/log"
        "${cfg.dataDir}/tmp"
      ]
      (n: {
        d = {
          user = cfg.user;
          group = cfg.group;
          mode = "0770";
        };
      })
      // {
        "${cfg.dataDir}".d = {
          user = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
      };

    systemd.services.sure-setup = {
      description = "Sure setup";
      requiredBy = ["sure.service"];
      before = ["sure.service"];
      after = lib.optional cfg.database.createLocally "postgresql.service";
      restartTriggers = [cfg.package];

      serviceConfig =
        cfgService
        // {
          Type = "oneshot";
          ExecStart = lib.getExe setupScript;
          RemainAfterExit = true;
        };
    };

    systemd.services.sure = {
      description = "Sure service";
      after =
        ["network-online.target" "sure-setup.service"]
        ++ lib.optional cfg.database.createLocally "postgresql.service"
        ++ lib.optional cfg.redis.createLocally "redis-sure.service";
      wants = ["network-online.target" "sure-setup.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig =
        cfgService
        // {
          ExecStart = "${cfg.package}/bin/sure";
          Restart = "on-failure";
        };

      environment = {
        BINDING = cfg.host;
        PORT = toString cfg.port;
      };
    };

    systemd.services.sure-worker = {
      description = "Sure Sidekiq Worker";
      after =
        ["sure-setup.service"]
        ++ lib.optional cfg.database.createLocally "postgresql.service"
        ++ lib.optional cfg.redis.createLocally "redis-sure.service";
      wants = ["sure-setup.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig =
        cfgService
        // {
          ExecStart = "${cfg.package}/bin/sure-worker";
          Restart = "on-failure";
        };
    };

    users.users = lib.mkIf (cfg.user == "sure") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        extraGroups = lib.optionals cfg.redis.createLocally ["redis"];
      };
    };

    users.groups = lib.mkIf (cfg.group == "sure") {
      ${cfg.group} = {};
    };
  };
}
