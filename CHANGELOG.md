# Changelog

All notable changes to this project will be documented in this file.

## Release 0.2.0

**Features**

* `app_admin_password` (and `app_admin_user`, default `admin`) sets
  homer-app's web interface password. Each run logs in with it and, only when
  that fails, sets it with `homer-app -update-ui-user`. Converted to
  `Sensitive` on lookup; empty (the default) leaves it alone.

## Release 0.1.0

First release on the Puppet Forge.

**Features**

* Installs heplify-server, homer-app and the heplify capture agent from QXIP's
  SIPCAPTURE APT repository, each turned on with its own `install_*`
  parameter. The repository's signing key is installed as a keyring with
  `signed-by`, not with `apt-key`.
* Every default lives in the module's Hiera data.
* heplify-server's `/etc/heplify-server.toml` and homer-app's
  `webapp_config.json` are generated from `server_settings` and
  `app_settings`, deep-merged across your Hiera hierarchy. Database settings
  come from the `db_*` parameters, including a remote host and port.
* homer-app's database user, databases and config tables are created once
  with `homer-app -initialize_db`, as a Sensitive command so the passwords
  stay out of logs and reports. `app_db_init` turns this off.
* Passwords are converted to `Sensitive` on lookup, and the generated files'
  diffs stay out of reports.
* heplify's command line is set with a systemd drop-in instead of replacing
  the unit file its package ships.
* Supports Puppet 7 and 8 on Debian 11 and 12.

**Bugfixes**

* The module compiles with `strict_variables`, the Puppet 8 default, and
  next to puppetlabs/postgresql.
* heplify-server's configuration is written where the package's unit reads it.
* homer-app's database user gets the configured password instead of
  homer-app's default.
* apt update runs before the packages are installed.
* heplify's unit runs `/usr/local/bin/heplify`, where the package installs it.

**Known Issues**

* The QXIP packages are amd64 only.
