# == Class: homer::agent
#
# Optional: installs the `heplify` HEP capture agent on this same host and
# points it at the local heplify-server.
#
# Off by default ($homer::install_agent).
#
class homer::agent {

  package { $homer::agent_package_name:
    ensure   => $homer::agent_package_ensure,
    provider => $homer::agent_package_provider,
    require  => $homer::agent_package_require,
  }

  file { $homer::agent_service_config_name:
    ensure  => $homer::agent_service_config_ensure,
    mode    => $homer::agent_service_config_mode,
    content => $homer::agent_service_config_content,
    notify  => $homer::agent_service_config_notify,
  }

  exec { 'homer-systemd-reload':
    command     => $homer::agent_service_reload_exec,
    refreshonly => true,
  }

  service { $homer::agent_service_name:
    ensure  => $homer::agent_service_ensure,
    enable  => $homer::agent_service_enable,
    require => $homer::agent_service_require,
  }
}
