# @summary Installs heplify and sets its command line.
#
# The heplify package ships a systemd unit. A drop-in replaces its command
# line with one built from the agent_* parameters, so package upgrades and
# Puppet never overwrite each other's files.
#
# @api private
class homer::agent {
  assert_private()

  $dropin_dir = "/etc/systemd/system/${homer::agent_service_name}.service.d"
  $dropin     = "${dropin_dir}/homer.conf"
  $command    = [
    '/usr/local/bin/heplify',
    '-i', $homer::agent_interface,
    '-hs', $homer::agent_hep_server,
    '-m', $homer::agent_capture_mode,
  ] + $homer::agent_options

  package { $homer::agent_package_name:
    ensure   => $homer::agent_package_ensure,
    provider => $homer::agent_package_provider,
  }

  file { $dropin_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { $dropin:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('homer/heplify.dropin.epp', { 'command' => $command.join(' ') }),
    notify  => Exec['homer-agent-systemd-daemon-reload'],
  }

  exec { 'homer-agent-systemd-daemon-reload':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
  }

  service { $homer::agent_service_name:
    ensure    => $homer::agent_service_ensure,
    enable    => $homer::agent_service_enable,
    require   => Package[$homer::agent_package_name],
    subscribe => [File[$dropin], Exec['homer-agent-systemd-daemon-reload']],
  }
}
