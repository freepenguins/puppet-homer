# @summary Adds QXIP's SIPCAPTURE APT repository.
#
# The repository provides heplify-server, homer-app and heplify. Debian's
# own repositories already carry PostgreSQL.
#
# @api private
class homer::repo {
  assert_private()

  if $homer::manage_repo {
    if $homer::repo_config.empty {
      unless $facts['os']['family'] == 'Debian' {
        $message = [
          "homer: manage_repo only sets up QXIP's APT repository, and this is a ${facts['os']['family']} system.",
          'Set homer::manage_repo to false and provide the packages from a repository you manage.',
        ].join(' ')
        fail($message)
      }

      # Strings rather than arrays: puppetlabs-apt accepts arrays only from
      # 10.0.0. With only `name` and `source` in the key hash, apt writes a
      # keyring and signed-by instead of using the deprecated apt-key.
      apt::source { $homer::repo_name:
        comment       => 'QXIP SIPCAPTURE APT repository',
        location      => $homer::repo_location,
        release       => $homer::repo_release,
        repos         => $homer::repo_components.join(' '),
        architecture  => $homer::repo_architectures.empty ? {
          true    => undef,
          default => $homer::repo_architectures.join(','),
        },
        pin           => $homer::repo_pin_priority,
        key           => {
          'name'   => $homer::repo_key_name,
          'source' => $homer::repo_key_source,
        },
        notify_update => true,
      }
    } else {
      $homer::repo_config.each |String[1] $resource_type, Hash $resources| {
        create_resources($resource_type, $resources, $homer::repo_config_defaults)
      }
    }
  }
}
