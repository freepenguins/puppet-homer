# == Class: homer::app
#
# Installs homer-app from QXIP's apt repo, writes webapp_config.json,
# runs the one-time DB initialization commands documented at
# https://github.com/sipcapture/homer/wiki/Quick-Install, and starts the
# homer-app service.
#
class homer::app {
  package { $homer::app_package_name:
    ensure   => $homer::app_package_ensure,
    require  => $homer::app_package_require,
    provider => $homer::app_package_provider,
  }

  file { $homer::app_config_path:
    ensure  => $homer::app_config_ensure,
    mode    => $homer::app_config_mode,
    owner   => $homer::app_config_owner,
    group   => $homer::app_config_group,
    content => $homer::app_config_content,
    notify  => $homer::app_config_notify,
    require => $homer::app_config_require,
  }

  # One-time DB bootstrap, mirrors the Quick-Install wiki verbatim.
  # A marker file makes the whole sequence idempotent instead of relying
  # on each homer-app subcommand's own idempotency.
  exec { 'homer-app-db-init':
    command => [
      "homer-app -create-config-db -database-root-user=postgres -database-host=127.0.0.1 -database-root-password='${homer::app_db_admin_password}' -database-homer-user=${homer::app_db_user}",
      "homer-app -create-data-db -database-root-user=postgres -database-host=127.0.0.1 -database-root-password='${homer::app_db_admin_password}' -database-homer-user=${homer::app_db_user}",
      'homer-app -create-table-db-config',
      'homer-app -populate-table-db-config',
      'homer-app -upgrade-table-db-config',
    ].join(' && '),
    path    => ['/usr/local/bin', '/usr/bin', '/bin'],
    creates => $homer::app_db_init_path,
    require => [File[$homer::app_config_path], Class['postgresql']],
  }

  file { $homer::app_db_init_path:
    ensure  => file,
    content => "bootstrapped by puppet\n",
    require => Exec['homer-app-db-init'],
  }

  service { $homer::app_service_name:
    ensure  => $homer::app_service_ensure,
    enable  => $homer::app_service_enable,
    require => $homer::app_service_require,
  }
}
