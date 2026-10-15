# == Class: homer::app
#
# Installs homer-app from QXIP's apt repo, writes webapp_config.json,
# runs `homer-app -initialize_db` once to create the database user,
# databases and config tables, and starts the homer-app service.
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

  # One-time database setup. -initialize_db creates the database user with
  # its password, the homer_data and homer_config databases, and the config
  # tables; the marker file below keeps it from running again. The command
  # carries passwords, so it is Sensitive and redacted from logs and reports.
  $db_init = [
    'homer-app -initialize_db',
    '-database-root-user=postgres',
    "-database-root-password=${stdlib::shell_escape($homer::db_admin_password)}",
    '-database-host=127.0.0.1',
    "-database-homer-user=${stdlib::shell_escape($homer::db_user)}",
    "-database-homer-password=${stdlib::shell_escape($homer::db_password)}",
    "-webapp-config-path=${stdlib::shell_escape($homer::app_config_dir)}",
  ].join(' ')

  exec { 'homer-app-db-init':
    command => Sensitive($db_init),
    path    => ['/usr/local/bin', '/usr/bin', '/bin'],
    creates => $homer::app_db_init_path,
    require => File[$homer::app_config_path],
    before  => Service[$homer::app_service_name],
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
