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
        then "localhost"
        else cfg.database.host;
      DB_PORT = cfg.database.port;
      POSTGRES_USER = cfg.database.user;
      POSTGRES_PASSWORD =
        if cfg.database.passwordFile != null
        then "@POSTGRES_PASSWORD@"
        else cfg.database.password;

      REDIS_URL =
        if cfg.redis.createLocally
        then "unix://${config.services.redis.servers.sure.unixSocket}"
        else if cfg.redis.password != null
        then "redis://:${cfg.redis.password}@${cfg.redis.host}:${toString cfg.redis.port}/${cfg.redis.name}"
        else if cfg.redis.passwordFile != null
        then "redis://:@REDIS_PASSWORD@@${cfg.redis.host}:${toString cfg.redis.port}/${cfg.redis.name}"
        else "redis://${cfg.redis.host}:${toString cfg.redis.port}/${cfg.redis.name}";

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
        env)} ${cfg.stateDir}/.env

      ${lib.optionalString (cfg.secretKeyBaseFile != null) ''
        replace-secret '@SECRET_KEY_BASE@' ${lib.escapeShellArg cfg.secretKeyBaseFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.database.passwordFile != null) ''
        replace-secret '@POSTGRES_PASSWORD@' ${lib.escapeShellArg cfg.database.passwordFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.redis.passwordFile != null) ''
        replace-secret '@REDIS_PASSWORD@' ${lib.escapeShellArg cfg.redis.passwordFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.twelveData.apiKeyFile != null) ''
        replace-secret '@TWELVE_DATA_API_KEY@' ${lib.escapeShellArg cfg.twelveData.apiKeyFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.openai.accessTokenFile != null) ''
        replace-secret '@OPENAI_ACCESS_TOKEN@' ${lib.escapeShellArg cfg.openai.accessTokenFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.langfuse.secretKeyFile != null) ''
        replace-secret '@LANGFUSE_SECRET_KEY@' ${lib.escapeShellArg cfg.langfuse.secretKeyFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.smtp.passwordFile != null) ''
        replace-secret '@SMTP_PASSWORD@' ${lib.escapeShellArg cfg.smtp.passwordFile} ${cfg.stateDir}/.env
      ''}

      ${lib.optionalString (cfg.oidc.clientSecretFile != null) ''
        replace-secret '@OIDC_CLIENT_SECRET@' ${lib.escapeShellArg cfg.oidc.clientSecretFile} ${cfg.stateDir}/.env
      ''}

      ${cfg.package}/bin/sure-rails db:migrate
    '';
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

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sure";
      description = "The root directory where all of the Sure's data is stored";
    };

    onboardingState = lib.mkOption {
      type = lib.types.enum ["open" "closed" "invite_only"];
      default = "open";
    };

    secretKeyBase = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    secretKeyBaseFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    appDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    productName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    brandName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
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

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "sure";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "sure";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "sure";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };

    exchangeRateProvider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["twelve_data" "yahoo_finance"]);
      default = "twelve_data";
    };

    securitiesProvider = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["twelve_data" "yahoo_finance"]);
      default = "twelve_data";
    };

    twelveData = {
      apiKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };

    openai = {
      accessToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;

      };

      accessTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      uriBase = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    langfuse = {
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "https://cloud.langfuse.com";
      };

      publicKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      secretKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      secretKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };

    smtp = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
      };

      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };

      tlsEnabled = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      emailSender = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    oidc = {
      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      clientSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };

      issuer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      redirectUri = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables to be merged with the main environment variables";
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
        assertion = cfg.redis.password == null || cfg.redis.passwordFile == null;
        message = "cannot set both services.sure.redis.password and services.sure.redis.passwordFile";
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

    services.redis.servers."${cfg.redis.name}" = lib.mkIf cfg.redis.createLocally (
      {
        enable = true;
        group = cfg.group;
      }
      // lib.optionalAttrs (cfg.redis.password != null) {requirePass = cfg.redis.password;}
      // lib.optionalAttrs (cfg.redis.passwordFile != null) {requirePassFile = cfg.redis.passwordFile;}
    );

    systemd.services.sure-setup = {
      description = "Sure setup";
      requiredBy = ["sure.service"];
      before = ["sure.service"];
      after = lib.optional cfg.database.createLocally "postgresql.service";
      restartTriggers = [cfg.package];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe setupScript;
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.package;
        ReadWritePaths = [cfg.stateDir];
        StateDirectory = "sure";
      };
    };

    systemd.services.sure-worker = {
      description = "Sure Sidekiq Worker";
      after =
        ["sure.service"]
        ++ lib.optional cfg.database.createLocally "postgresql.service"
        ++ lib.optional cfg.redis.createLocally "redis-sure.service";
      wants = ["sure.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/sure-worker";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        WorkingDirectory = cfg.package;
        ReadWritePaths = [cfg.stateDir];
        StateDirectory = "sure";
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

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/sure";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        WorkingDirectory = cfg.package;
        ReadWritePaths = [cfg.stateDir];
        StateDirectory = "sure";
      };

      environment = {
        BINDING = cfg.host;
        PORT = toString cfg.port;
      };
    };

    users.users = lib.mkIf (cfg.user == "sure") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.stateDir;
        extraGroups = lib.optionals cfg.redis.createLocally ["redis"];
      };
    };

    users.groups = lib.mkIf (cfg.group == "sure") {
      ${cfg.group} = {};
    };
  };
}
