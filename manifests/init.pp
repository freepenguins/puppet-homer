class homer (

  String                                                   $db_user                      = 'homer_user',
  String                                                   $db_password                  = 'homer_password',
  String                                                   $db_admin_password            = 'postgresql_password',
  Boolean                                                  $install_agent                = false,
  Boolean                                                  $install_app                  = false,
  Boolean                                                  $install_server               = false,
  Boolean                                                  $manage_repo                  = true,
  String                                                   $repo_name                    = 'sipcapture_official',
  Stdlib::HTTPUrl                                          $repo_location                = 'https://packagecloud.io/qxip/sipcapture/debian/',
  String[1]                                                $repo_release                 = $facts['os']['distro']['codename'],
  Array[String[1]]                                         $repo_components              = ['main'],
  String[1]                                                $repo_key_name                = 'homer-repo.gpg',
  Stdlib::HTTPUrl                                          $repo_key_source              = 'https://packagecloud.io/qxip/sipcapture/gpgkey',
  Optional[String[1]]                                      $repo_key_id                  = '8AE3BC335C18EB6F',
  Array[String[1]]                                         $repo_architectures           = [],
  Optional[Integer]                                        $repo_pin_priority            = undef,
  Hash                                                     $repo_config                  = {},
  Hash                                                     $repo_config_defaults         = {},
  Hash                                                     $configs                      = {},
  Hash                                                     $configs_defaults             = {},
  String                                                   $app_base_dir                 = '/usr/local/homer',
  String                                                   $app_config_dir               = '/usr/local/homer/etc',
  String                                                   $app_config_path              = '/usr/local/homer/etc/webapp_config.json',
  String                                                   $app_config_ensure            = 'file',
  String                                                   $app_config_mode              = '0640',
  String                                                   $app_config_owner             = 'root',
  String                                                   $app_config_group             = 'root',
  String                                                   $app_config_content           = epp('homer/webapp_config.json.epp', { 'db_user' => $db_user, 'db_password' => $db_password, }),
  String                                                   $app_db_init_path             = "${app_base_dir}/.homerapp-db-initialized",
  String                                                   $app_package_name             = 'homer-app',
  String                                                   $app_package_ensure           = 'present',
  Optional[String[1]]                                      $app_package_provider         = undef,
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $app_package_require          = undef,
  String                                                   $app_service_name             = 'homer-app',
  String                                                   $app_service_ensure           = 'running',
  Boolean                                                  $app_service_enable           = true,
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $app_config_notify            = Service[$app_service_name],
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $app_config_require           = Package[$app_package_name],
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $app_service_require          = Package[$app_package_name],
  String                                                   $agent_capture_interface      = 'enp1s0',
  String                                                   $agent_package_ensure         = 'installed',
  String                                                   $agent_package_name           = 'heplify',
  Optional[String[1]]                                      $agent_package_provider       = undef,
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $agent_package_require        = undef,
  String                                                   $agent_service_ensure         = 'running',
  Boolean                                                  $agent_service_enable         = true,
  String                                                   $agent_service_name           = 'heplify',
  String                                                   $agent_service_config_ensure  = 'file',
  String                                                   $agent_service_config_mode    = '0644',
  String                                                   $agent_service_config_name    = '/etc/systemd/system/heplify.service',
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $agent_service_config_notify  = [Exec['homer-systemd-reload'], Service[$agent_service_name]],
  String                                                   $agent_service_reload_exec    = '/bin/systemctl daemon-reload',
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $agent_service_require        = [Package[$agent_package_name], File[$agent_service_config_name]],
  String                                                   $agent_service_config_content = epp('homer/heplify.service.epp', { 'interface' => $agent_capture_interface, }),
  String                                                   $server_package_ensure        = 'installed',
  String                                                   $server_package_name          = 'heplify-server',
  Optional[String[1]]                                      $server_package_provider      = undef,
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $server_package_require       = undef,
  String                                                   $server_service_ensure        = 'running',
  Boolean                                                  $server_service_enable        = true,
  String                                                   $server_service_name          = 'heplify-server',
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $server_service_require       = [Package[$server_package_name]],
  String                                                   $server_config_ensure         = 'file',
  String                                                   $server_config_mode           = '0640',
  String                                                   $server_config_owner          = 'root',
  String                                                   $server_config_group          = 'root',
  String                                                   $server_config_path           = '/etc/heplify-server.toml',
  String                                                   $server_config_content        = epp('homer/heplify-server.toml.epp', { 'db_user' => $db_user, 'db_password' => $db_password, 'config_path' => $server_config_path, }),
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $server_config_notify         = Service[$server_service_name],
  Optional[Variant[Array[Type[Resource]], Type[Resource]]] $server_config_require        = Package[$server_package_name],

) {
  contain homer::repo

  if $homer::install_server {
    contain homer::server
  }

  if $homer::install_app {
    contain homer::app
  }

  if $homer::install_agent {
    contain homer::agent
  }

  if $homer::install_server {
    Class['homer::repo'] -> Class['homer::server']
  }

  if $homer::install_app {
    Class['homer::repo'] -> Class['homer::app']
  }

  if $homer::install_agent {
    Class['homer::repo'] -> Class['homer::agent']
  }

  if $homer::manage_repo and $homer::repo_config.empty {
    if $homer::install_server {
      Class['apt::update'] -> Class['homer::server']
    }
    if $homer::install_app {
      Class['apt::update'] -> Class['homer::app']
    }
    if $homer::install_agent {
      Class['apt::update'] -> Class['homer::agent']
    }
  }

  create_resources(file, $homer::configs, $homer::configs_defaults)
}
