# @summary Installs HOMER 7 from the QXIP SIPCAPTURE package repository.
#
# HOMER 7 has three parts, each installed from QXIP's packages and turned on
# with its own `install_*` parameter:
#
# * heplify-server receives HEP from SIP servers and capture agents and
#   stores it in PostgreSQL (`install_server`).
# * homer-app is the web interface and API (`install_app`). On its first run
#   it creates the database user, the `homer_data` and `homer_config`
#   databases and the config tables with `homer-app -initialize_db`.
# * heplify is a capture agent that sends what it sees to heplify-server
#   (`install_agent`).
#
# PostgreSQL is not managed by this module. homer-app's database setup logs
# in as `db_admin_user` with a password, so that account needs password
# authentication from this host. Every parameter has a default in the
# module's Hiera data.
#
# @example A complete HOMER server
#   class { 'homer':
#     install_server    => true,
#     install_app       => true,
#     db_password       => Sensitive('change-me'),
#     db_admin_password => Sensitive('postgres-superuser-password'),
#   }
#
# @example The same from Hiera
#   homer::install_server: true
#   homer::install_app: true
#   homer::db_password: 'change-me'
#   homer::db_admin_password: 'postgres-superuser-password'
#
# @param install_server
#   Install, configure and run heplify-server.
# @param install_app
#   Install, configure and run homer-app.
# @param install_agent
#   Install and run the heplify capture agent.
# @param db_host
#   PostgreSQL host heplify-server and homer-app connect to.
# @param db_port
#   PostgreSQL port.
# @param db_user
#   Database user heplify-server and homer-app connect as. homer-app's setup
#   creates it.
# @param db_password
#   Password of `db_user`. Converted to `Sensitive` on lookup.
# @param db_data_name
#   Database holding captured HEP data.
# @param db_config_name
#   Database holding homer-app's settings.
# @param db_admin_user
#   PostgreSQL superuser homer-app's one-time setup logs in as.
# @param db_admin_password
#   Password of `db_admin_user`. Converted to `Sensitive` on lookup.
# @param manage_repo
#   Add QXIP's APT repository. Only Debian-family systems are supported; set
#   this to `false` to install the packages from a repository you manage.
# @param repo_name
#   Name of the `apt::source` resource.
# @param repo_location
#   Repository URL.
# @param repo_release
#   Repository suite. Defaults to the distribution's codename.
# @param repo_components
#   Repository components.
# @param repo_key_name
#   File name of the repository's signing key in `/etc/apt/keyrings`.
# @param repo_key_source
#   URL of the repository's signing key.
# @param repo_architectures
#   Architectures to fetch from the repository; empty means apt's default.
# @param repo_pin_priority
#   APT pin priority for the repository, or `undef` for none.
# @param repo_config
#   Resources to declare instead of the default `apt::source`, keyed by
#   resource type and then by title, for example
#   `{ 'apt::source' => { 'mirror' => { ... } } }`. When not empty, the
#   `repo_*` settings above are ignored.
# @param repo_config_defaults
#   Default attributes for the resources in `repo_config`.
# @param server_package_name
#   heplify-server package.
# @param server_package_ensure
#   `ensure` of the heplify-server package: `installed`, `latest` or a version.
# @param server_package_provider
#   Package provider, or `undef` for the system default.
# @param server_config_path
#   heplify-server configuration file. The package's systemd unit reads
#   `/etc/heplify-server.toml`.
# @param server_settings
#   heplify-server settings written to `server_config_path`, keyed by their
#   heplify-server names. Deep-merged across your Hiera hierarchy over the
#   module defaults. The database settings (`DBAddr`, `DBUser`, `DBPass`,
#   `DBDataTable`, `DBConfTable`) always come from the `db_*` parameters.
# @param server_service_name
#   heplify-server service.
# @param server_service_ensure
#   Whether heplify-server should be running.
# @param server_service_enable
#   Whether heplify-server starts at boot.
# @param app_package_name
#   homer-app package.
# @param app_package_ensure
#   `ensure` of the homer-app package.
# @param app_package_provider
#   Package provider, or `undef` for the system default.
# @param app_config_dir
#   Directory homer-app reads `webapp_config.json` from.
# @param app_settings
#   homer-app settings written to `webapp_config.json`. Deep-merged across
#   your Hiera hierarchy over the module defaults. The database connection
#   settings always come from the `db_*` parameters.
# @param app_db_init
#   Run homer-app's one-time database setup. Turn it off if the databases
#   already exist.
# @param app_db_init_marker
#   File written after the database setup succeeds; while it exists the
#   setup does not run again.
# @param app_service_name
#   homer-app service.
# @param app_service_ensure
#   Whether homer-app should be running.
# @param app_service_enable
#   Whether homer-app starts at boot.
# @param agent_package_name
#   heplify package.
# @param agent_package_ensure
#   `ensure` of the heplify package.
# @param agent_package_provider
#   Package provider, or `undef` for the system default.
# @param agent_interface
#   Interface heplify captures on; `any` captures on all of them.
# @param agent_hep_server
#   Where heplify sends HEP, as `host:port`; comma-separated for several.
# @param agent_capture_mode
#   heplify capture mode, such as `SIP` or `SIPRTCP`.
# @param agent_options
#   Further heplify command-line options, for example `['-hi', '2002']`.
# @param agent_service_name
#   heplify service. The package's unit is kept; this module adds a drop-in
#   that sets the command line.
# @param agent_service_ensure
#   Whether heplify should be running.
# @param agent_service_enable
#   Whether heplify starts at boot.
# @param configs
#   Further `file` resources to declare, keyed by path, such as homer-app's
#   TLS certificate.
# @param configs_defaults
#   Default attributes for the resources in `configs`.
class homer (
  Boolean                                     $install_server,
  Boolean                                     $install_app,
  Boolean                                     $install_agent,
  Stdlib::Host                                $db_host,
  Stdlib::Port                                $db_port,
  String[1]                                   $db_user,
  Variant[String[1], Sensitive[String[1]]]    $db_password,
  String[1]                                   $db_data_name,
  String[1]                                   $db_config_name,
  String[1]                                   $db_admin_user,
  Variant[String, Sensitive[String]]          $db_admin_password,
  Boolean                                     $manage_repo,
  String[1]                                   $repo_name,
  Stdlib::HTTPUrl                             $repo_location,
  String[1]                                   $repo_release,
  Array[String[1], 1]                         $repo_components,
  String[1]                                   $repo_key_name,
  Stdlib::HTTPUrl                             $repo_key_source,
  Array[String[1]]                            $repo_architectures,
  Optional[Integer]                           $repo_pin_priority,
  Hash[String[1], Hash]                       $repo_config,
  Hash                                        $repo_config_defaults,
  String[1]                                   $server_package_name,
  String[1]                                   $server_package_ensure,
  Optional[String[1]]                         $server_package_provider,
  Stdlib::Absolutepath                        $server_config_path,
  Hash[String[1], Homer::ServerSetting]       $server_settings,
  String[1]                                   $server_service_name,
  Stdlib::Ensure::Service                     $server_service_ensure,
  Boolean                                     $server_service_enable,
  String[1]                                   $app_package_name,
  String[1]                                   $app_package_ensure,
  Optional[String[1]]                         $app_package_provider,
  Stdlib::Absolutepath                        $app_config_dir,
  Hash[String[1], Any]                        $app_settings,
  Boolean                                     $app_db_init,
  Stdlib::Absolutepath                        $app_db_init_marker,
  String[1]                                   $app_service_name,
  Stdlib::Ensure::Service                     $app_service_ensure,
  Boolean                                     $app_service_enable,
  String[1]                                   $agent_package_name,
  String[1]                                   $agent_package_ensure,
  Optional[String[1]]                         $agent_package_provider,
  Homer::Word                                 $agent_interface,
  Homer::Word                                 $agent_hep_server,
  Homer::Word                                 $agent_capture_mode,
  Array[Homer::Word]                          $agent_options,
  String[1]                                   $agent_service_name,
  Stdlib::Ensure::Service                     $agent_service_ensure,
  Boolean                                     $agent_service_enable,
  Hash[String[1], Hash]                       $configs,
  Hash                                        $configs_defaults,
) {
  contain homer::repo

  if $install_server {
    contain homer::server
    Class['homer::repo'] -> Class['homer::server']
  }

  if $install_app {
    contain homer::app
    Class['homer::repo'] -> Class['homer::app']
  }

  if $install_agent {
    contain homer::agent
    Class['homer::repo'] -> Class['homer::agent']
  }

  # apt update has to run after the QXIP source is added and before its
  # packages are installed.
  if $manage_repo and $repo_config.empty {
    if $install_server {
      Class['apt::update'] -> Class['homer::server']
    }
    if $install_app {
      Class['apt::update'] -> Class['homer::app']
    }
    if $install_agent {
      Class['apt::update'] -> Class['homer::agent']
    }
  }

  $configs.each |String[1] $title, Hash $attributes| {
    file { $title:
      * => $configs_defaults + $attributes,
    }
  }
}
