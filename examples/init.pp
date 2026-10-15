# A HOMER server: heplify-server and homer-app with a local PostgreSQL.
class { 'homer':
  install_server    => true,
  install_app       => true,
  db_password       => Sensitive('change-me'),
  db_admin_password => Sensitive('postgres-superuser-password'),
}
