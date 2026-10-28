# A HOMER server: heplify-server and homer-app with a local PostgreSQL,
# and the web interface's admin password.
class { 'homer':
  install_server     => true,
  install_app        => true,
  db_password        => Sensitive('change-me'),
  db_admin_password  => Sensitive('postgres-superuser-password'),
  app_admin_password => Sensitive('ui-change-me'),
}
