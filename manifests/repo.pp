# == Class: homer::repo
#
# Adds the two third-party apt sources this stack needs:
#   - QXIP's packagecloud repo (heplify-server, homer-app, heplify)
#
# Debian's own repos already carry postgresql, prometheus,
# prometheus-alertmanager and prometheus-node-exporter
#
# subclasses are private and read the main class directly now
# @api private
class homer::repo {
  assert_private()

  if $homer::manage_repo {
    if $homer::repo_config.empty {
      apt::source { $homer::repo_name :
        comment       => 'QXIP SIPcapture APT Repository',
        location      => $homer::repo_location,
        release       => [$homer::repo_release],
        repos         => $homer::repo_components,
        architecture  => $homer::repo_architectures,
        pin           => $homer::repo_pin_priority,
        key           => {
          'name'   => $homer::repo_key_name,
          'source' => $homer::repo_key_source,
          'id'     => $homer::repo_key_id,
        },
        notify_update => true,
      }

      if $homer::manage_package {
        Apt::Source[$homer::repo_name] -> Package[$homer::package_name]
      }
    } else {
      $homer::repo_config.each() | String[1] $resource_type, Hash $resources | {
        create_resources($resource_type, $resources, $homer::repo_config_defaults)
      }
    }
  }
}
