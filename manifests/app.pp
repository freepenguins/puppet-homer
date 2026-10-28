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

  $login_file = "${homer::app_config_dir}/.admin_login.json"

  $admin_password = $homer::app_admin_password ? {
    Sensitive => $homer::app_admin_password.unwrap,
    default   => $homer::app_admin_password,
  }

  if $admin_password != '' {
    $http_host = $settings.dig('http_settings', 'host').lest || { '127.0.0.1' }
    $login_host = $http_host ? {
      /\A(0\.0\.0\.0|::|)\z/ => '127.0.0.1',
      default              => $http_host,
    }
    $login_port = $settings.dig('http_settings', 'port').lest || { 9080 }
    $login_url = "http://${login_host}:${login_port}/api/v3/auth"

    # The login body the check posts, so the password never appears on its
    # command line. Root-only, like webapp_config.json.
    file { $login_file:
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0600',
      show_diff => false,
      content   => Sensitive(stdlib::to_json({ 'username' => $homer::app_admin_user, 'password' => $admin_password })),
      require   => Package[$homer::app_package_name],
    }

    file { '/usr/local/sbin/homer-app-login-check':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/homer/homer-app-login-check',
    }

    # homer-app stores the password as a bcrypt hash, so the only way to
    # compare is to log in. When the login fails (a new password, or
    # homer-app not answering yet), set it with homer-app's own flag; it
    # is a no-op when the password already matches. homer-app only takes
    # the password on its command line, so it is visible in the process
    # list while this runs.
    $update = [
      'homer-app',
      "-update-ui-user=${stdlib::shell_escape($homer::app_admin_user)}",
      "-update-ui-password=${stdlib::shell_escape($admin_password)}",
      "-webapp-config-path=${stdlib::shell_escape($homer::app_config_dir)}",
    ].join(' ')

    exec { 'homer-app-admin-password':
      command => Sensitive($update),
      unless  => "/usr/local/sbin/homer-app-login-check ${stdlib::shell_escape($login_url)} ${stdlib::shell_escape($login_file)}",
      path    => ['/usr/local/bin', '/usr/bin', '/bin'],
      require => [File[$login_file, '/usr/local/sbin/homer-app-login-check'], Service[$homer::app_service_name]],
    }
  } else {
    file { $login_file:
      ensure => absent,
    }
  }
}
