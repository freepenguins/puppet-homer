# homer

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with homer](#setup)
    * [What homer affects](#what-homer-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with homer](#beginning-with-homer)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module installs [HOMER 7](https://sipcapture.org), the VoIP capture and
troubleshooting platform, from QXIP's SIPCAPTURE package repository. HOMER has
three parts, and each one is switched on separately:

* **heplify-server** (`install_server`) receives HEP from SIP servers and
  capture agents and stores it in PostgreSQL.
* **homer-app** (`install_app`) is the web interface and API. On its first run
  the module creates the database user, the `homer_data` and `homer_config`
  databases and the config tables with `homer-app -initialize_db`.
* **heplify** (`install_agent`) is a capture agent that sends what it sees on
  the wire to heplify-server.

Every setting is a parameter of the `homer` class with a default in the
module's Hiera data, so you configure it with `homer::*` keys in your own
Hiera. heplify-server's and homer-app's configuration files are generated from
settings hashes that you can extend from Hiera.

## Setup

### What homer affects

* An APT source for `https://packagecloud.io/qxip/sipcapture/debian/` and its
  signing key in `/etc/apt/keyrings/homer-repo.gpg` (`manage_repo`).
* With `install_server`: the `heplify-server` package,
  `/etc/heplify-server.toml` and the `heplify-server` service.
* With `install_app`: the `homer-app` package,
  `/usr/local/homer/etc/webapp_config.json` (mode 0600, as the package installs
  it), a one-time database setup recorded in
  `/usr/local/homer/.homerapp-db-initialized`, and the `homer-app` service.
* With `install_agent`: the `heplify` package, a systemd drop-in at
  `/etc/systemd/system/heplify.service.d/homer.conf` that sets heplify's
  command line, and the `heplify` service. The unit file the package ships is
  left alone.

### Setup requirements

* Puppet 7 or 8 with puppetlabs/stdlib and puppetlabs/apt (9.2 or later).
* A PostgreSQL server. The module does not install or configure PostgreSQL.
  homer-app's one-time setup connects to `db_host` as the superuser
  `db_admin_user` with `db_admin_password`, so that account needs password
  authentication from this host. After that, heplify-server and homer-app
  connect as `db_user`.

### Beginning with homer

A HOMER server with heplify-server and homer-app, using a local PostgreSQL:

```yaml
homer::install_server: true
homer::install_app: true
homer::db_password: 'change-me'
homer::db_admin_password: 'postgres-superuser-password'
```

Both passwords are converted to `Sensitive` on lookup. Keep them out of plain
Hiera with [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) or a similar
backend.

Then sign in to `http://<host>:9080` as `admin` with the password
`sipcapture`, homer-app's default, and change it.

## Usage

### PostgreSQL on the same host with puppetlabs/postgresql

```puppet
class { 'postgresql::server':
  postgres_password => Sensitive('postgres-superuser-password'),
}

class { 'homer':
  install_server    => true,
  install_app       => true,
  db_password       => Sensitive('change-me'),
  db_admin_password => Sensitive('postgres-superuser-password'),
  require           => Class['postgresql::server'],
}
```

### A remote database

```yaml
homer::db_host: 'db.example.com'
homer::db_port: 5432
```

Both heplify-server and homer-app use these settings. `db_*` parameters always
win over the same settings in `server_settings` or `app_settings`.

### Change heplify-server settings

`homer::server_settings` uses heplify-server's own setting names. Your values
are deep-merged with the module's defaults, so list only what you change:

```yaml
homer::server_settings:
  HEPTCPAddr: '0.0.0.0:9061'     # also accept HEP over TCP
  PromAddr: '127.0.0.1:9096'     # Prometheus metrics
  DBDropDays: 30                 # keep 30 days of data
  DiscardMethod:
    - OPTIONS
```

The module turns off heplify-server's TLS and WebSocket listeners by default.
Its built-in WebSocket port, 3000, is the port Grafana usually uses.

### Change homer-app settings

`homer::app_settings` is `webapp_config.json` as YAML, deep-merged the same
way. For example, to set the JWT secret and move the web interface to port
8080:

```yaml
homer::app_settings:
  auth_settings:
    jwt_secret: 'a-long-random-string'
  http_settings:
    port: 8080
```

To serve HTTPS, put the certificate and key in place with `homer::configs`
and turn on `https_settings`:

```yaml
homer::configs:
  /usr/local/homer/tls/cert.pem:
    source: 'puppet:///modules/profile/homer/cert.pem'
  /usr/local/homer/tls/key.pem:
    source: 'puppet:///modules/profile/homer/key.pem'
homer::configs_defaults:
  ensure: file
  owner: root
  group: root
  mode: '0600'
homer::app_settings:
  https_settings:
    enable: true
```

### Capture on a SIP server

On a host that should only capture and send HEP to a HOMER server elsewhere:

```yaml
homer::install_agent: true
homer::agent_interface: 'eth0'
homer::agent_hep_server: 'homer.example.com:9060'
homer::agent_capture_mode: 'SIP'
homer::agent_options:
  - '-hi'
  - '2002'
```

`agent_hep_server` takes several comma-separated destinations.

### Databases that already exist

If the databases and user were created some other way, skip homer-app's setup:

```yaml
homer::app_db_init: false
```

To run the setup again, delete `/usr/local/homer/.homerapp-db-initialized`.

### Packages from your own repository

```yaml
homer::manage_repo: false
```

Or keep `manage_repo` and declare your own source in place of QXIP's:

```yaml
homer::repo_config:
  apt::source:
    sipcapture_mirror:
      location: 'https://mirror.example.com/sipcapture/'
      release: 'bookworm'
      repos: 'main'
```

## Reference

See [REFERENCE.md](REFERENCE.md) for every parameter.

## Limitations

* Debian 11 and 12. The QXIP repository is set up only on Debian-family
  systems; elsewhere, set `manage_repo` to `false` and provide the packages.
  QXIP publishes the packages to packagecloud's catch-all distribution; if
  `debian/<codename>` does not serve them on your release, point
  `repo_location` and `repo_release` at a suite that does.
* The packages are amd64 only.
* PostgreSQL is not managed.
* freepenguins/heplify can also run heplify-server and heplify, installed from
  their release binaries. Use one module or the other for each service on a
  host, not both.
* On Puppet 7, use puppetlabs/stdlib 9.x.

## Development

This module was created from the
[PDK templates](https://github.com/puppetlabs/pdk-templates). Run the usual PDK
commands from the module root:

```shell
pdk validate
pdk test unit
pdk build
```

The module is pinned to pdk-templates 3.8.0 (`template-url` in
`metadata.json`). Its Gemfile installs Puppet from the public rubygems.org
unless `PUPPET_FORGE_TOKEN` is set, in which case it uses the Puppet Core gem
source. pdk-templates 4.x makes Puppet Core the default, and its only opt-out
is a Bundler setting that PDK ignores, so `pdk validate` cannot use public gems
with those templates. Keep the pin unless you have Puppet Core credentials.

To test against a specific Puppet version without PDK:

```shell
PUPPET_GEM_VERSION='~> 7' bundle exec rake spec
PUPPET_GEM_VERSION='~> 8' bundle exec rake spec
```

Regenerate `REFERENCE.md` after changing parameters or their documentation:

```shell
pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```

Bug reports and pull requests are welcome at
<https://github.com/freepenguins/puppet-homer>.
