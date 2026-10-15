# @summary Installs and configures heplify-server.
#
# @api private
class homer::server {
  assert_private()

  $db_password = $homer::db_password ? {
    Sensitive => $homer::db_password.unwrap,
    default   => $homer::db_password,
  }

  # The database settings come from the db_* parameters, whatever
  # server_settings holds.
  $settings = $homer::server_settings + {
    'DBAddr'      => "${homer::db_host}:${homer::db_port}",
    'DBUser'      => $homer::db_user,
    'DBPass'      => $db_password,
    'DBDataTable' => $homer::db_data_name,
    'DBConfTable' => $homer::db_config_name,
  }

  package { $homer::server_package_name:
    ensure   => $homer::server_package_ensure,
    provider => $homer::server_package_provider,
  }

  # heplify-server silently falls back to its built-in defaults when this
  # file is not valid TOML, so it is generated rather than templated. It
  # holds the database password, so its diff stays out of reports.
  file { $homer::server_config_path:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0640',
    show_diff => false,
    content   => stdlib::to_toml($settings),
    require   => Package[$homer::server_package_name],
    notify    => Service[$homer::server_service_name],
  }

  service { $homer::server_service_name:
    ensure  => $homer::server_service_ensure,
    enable  => $homer::server_service_enable,
    require => Package[$homer::server_package_name],
  }
}
