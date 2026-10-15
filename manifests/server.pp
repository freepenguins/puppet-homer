# == Class: homer::server
#
# Installs heplify-server from QXIP's apt repo and configures it via
# /etc/heplify-server/heplify-server.toml (packaged default path; the
# wiki's manual-build guide instead used /opt/heplify-server -- adjust
# $config_path if your packaged layout differs).
#
class homer::server {
  package { $homer::server_package_name:
    ensure   => $homer::server_package_ensure,
    provider => $homer::server_package_provider,
    require  => $homer::server_package_require,
  }

  file { $homer::server_config_path:
    ensure  => $homer::server_config_ensure,
    mode    => $homer::server_config_mode,
    owner   => $homer::server_config_owner,
    group   => $homer::server_config_group,
    content => $homer::server_config_content,
    require => $homer::server_config_require,
    notify  => $homer::server_config_notify,
  }

  service { $homer::server_service_name:
    ensure  => $homer::server_service_ensure,
    enable  => $homer::server_service_enable,
    require => $homer::server_service_require,
  }
}
