# @summary Installs and configures homer-app and sets up its databases.
#
# @api private
class homer::app {
  assert_private()

  $db_password = $homer::db_password ? {
    Sensitive => $homer::db_password.unwrap,
    default   => $homer::db_password,
  }
  $db_admin_password = $homer::db_admin_password ? {
    Sensitive => $homer::db_admin_password.unwrap,
    default   => $homer::db_admin_password,
  }

  # The database connections come from the db_* parameters, whatever
  # app_settings holds.
  $connection = {
    'host' => $homer::db_host,
    'port' => $homer::db_port,
    'user' => $homer::db_user,
    'pass' => $db_password,
  }
  $db_settings = {
    'database_data'   => { 'LocalNode' => $connection + { 'name' => $homer::db_data_name } },
    'database_config' => $connection + { 'name' => $homer::db_config_name },
  }
  $settings = homer::deep_merge($homer::app_settings, $db_settings)
  $config_file = "${homer::app_config_dir}/webapp_config.json"

  package { $homer::app_package_name:
    ensure   => $homer::app_package_ensure,
    provider => $homer::app_package_provider,
  }

  # The package installs this file with mode 0600 because it holds the
  # database password; its diff stays out of reports.
  file { $config_file:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0600',
    show_diff => false,
    content   => stdlib::to_json_pretty($settings),
    require   => Package[$homer::app_package_name],
    notify    => Service[$homer::app_service_name],
  }

  if $homer::app_db_init {
    # -initialize_db creates the database user with its password, both
    # databases and the config tables. The command carries passwords, so it
    # is Sensitive and redacted from logs and reports.
    $db_init = [
      'homer-app -initialize_db',
      "-database-host=${stdlib::shell_escape($homer::db_host)}",
      "-database-port=${homer::db_port}",
      "-database-root-user=${stdlib::shell_escape($homer::db_admin_user)}",
      "-database-root-password=${stdlib::shell_escape($db_admin_password)}",
      "-database-homer-user=${stdlib::shell_escape($homer::db_user)}",
      "-database-homer-password=${stdlib::shell_escape($db_password)}",
      "-database-homer-data=${stdlib::shell_escape($homer::db_data_name)}",
      "-database-homer-config=${stdlib::shell_escape($homer::db_config_name)}",
      "-webapp-config-path=${stdlib::shell_escape($homer::app_config_dir)}",
    ].join(' ')

    exec { 'homer-app-db-init':
      command => Sensitive($db_init),
      path    => ['/usr/local/bin', '/usr/bin', '/bin'],
      creates => $homer::app_db_init_marker,
      require => File[$config_file],
      before  => Service[$homer::app_service_name],
    }

    file { $homer::app_db_init_marker:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "homer-app -initialize_db has run; delete this file to run it again.\n",
      require => Exec['homer-app-db-init'],
    }
  }

  service { $homer::app_service_name:
    ensure  => $homer::app_service_ensure,
    enable  => $homer::app_service_enable,
    require => Package[$homer::app_package_name],
  }
}
