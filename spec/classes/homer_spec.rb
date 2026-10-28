# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'homer' do
  server_toml = '/etc/heplify-server.toml'
  webapp_json = '/usr/local/homer/etc/webapp_config.json'
  marker = '/usr/local/homer/.homerapp-db-initialized'
  dropin = '/etc/systemd/system/heplify.service.d/homer.conf'
  login_json = '/usr/local/homer/etc/.admin_login.json'
  check = '/usr/local/sbin/homer-app-login-check'

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:codename) { os_facts[:os]['distro']['codename'] }
      let(:webapp) { JSON.parse(catalogue.resource('File', webapp_json)[:content]) }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('homer::repo') }
        it { is_expected.not_to contain_class('homer::server') }
        it { is_expected.not_to contain_class('homer::app') }
        it { is_expected.not_to contain_class('homer::agent') }

        it {
          is_expected.to contain_apt__source('sipcapture_official').with(
            location: 'https://packagecloud.io/qxip/sipcapture/debian/',
            release: codename,
            repos: 'main',
            architecture: nil,
            key: { 'name' => 'homer-repo.gpg', 'source' => 'https://packagecloud.io/qxip/sipcapture/gpgkey' },
          )
        }

        # A keyring with signed-by, not the deprecated apt-key.
        it { is_expected.to contain_apt__keyring('homer-repo.gpg') }
      end

      context 'with install_server => true' do
        let(:params) { { install_server: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify-server').with_ensure('installed') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::server]') }

        it {
          is_expected.to contain_file(server_toml)
            .with(owner: 'root', group: 'root', mode: '0640', show_diff: false)
            .that_requires('Package[heplify-server]')
            .that_notifies('Service[heplify-server]')
        }

        it { is_expected.to contain_file(server_toml).with_content(%r{^HEPAddr = "0\.0\.0\.0:9060"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^HEPWSAddr = ""$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBShema = "homer7"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBAddr = "127\.0\.0\.1:5432"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBUser = "homer_user"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBPass = "homer_password"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBDataTable = "homer_data"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBConfTable = "homer_config"$}) }
        it { is_expected.to contain_service('heplify-server').with(ensure: 'running', enable: true).that_requires('Package[heplify-server]') }
      end

      context 'with server_settings and database parameters' do
        let(:params) do
          {
            install_server: true,
            db_host: 'db.example.com',
            db_port: 5433,
            db_password: sensitive('s3cr"et'),
            server_settings: { 'PromAddr' => '127.0.0.1:9096', 'DiscardMethod' => ['OPTIONS'], 'DBUser' => 'ignored' },
          }
        end

        it { is_expected.to contain_file(server_toml).with_content(%r{^PromAddr = "127\.0\.0\.1:9096"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DiscardMethod = \["OPTIONS"\]$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBAddr = "db\.example\.com:5433"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBPass = "s3cr\\"et"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBUser = "homer_user"$}) }
      end

      context 'with install_app => true' do
        let(:params) { { install_app: true, db_admin_password: 'pg-root' } }
        let(:db_init) do
          [
            'homer-app -initialize_db', '-database-host=127.0.0.1', '-database-port=5432', '-database-root-user=postgres',
            '-database-root-password=pg-root', '-database-homer-user=homer_user', '-database-homer-password=homer_password',
            '-database-homer-data=homer_data', '-database-homer-config=homer_config', '-webapp-config-path=/usr/local/homer/etc'
          ].join(' ')
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('homer-app').with_ensure('installed') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::app]') }

        it {
          is_expected.to contain_file(webapp_json)
            .with(owner: 'root', group: 'root', mode: '0600', show_diff: false)
            .that_requires('Package[homer-app]')
            .that_notifies('Service[homer-app]')
        }

        it 'connects homer-app to both databases with the db_* settings' do
          expect(webapp['database_data']['LocalNode']).to include(
            'host' => '127.0.0.1', 'port' => 5432, 'user' => 'homer_user', 'pass' => 'homer_password', 'name' => 'homer_data', 'node' => 'LocalNode',
          )
          expect(webapp['database_config']).to include(
            'host' => '127.0.0.1', 'port' => 5432, 'user' => 'homer_user', 'pass' => 'homer_password', 'name' => 'homer_config', 'node' => 'LocalConfig',
          )
        end

        it 'keeps the other webapp settings' do
          expect(webapp['http_settings']).to include('port' => 9080, 'root' => '/usr/local/homer/dist')
          expect(webapp['auth_settings']['user_groups']).to eq(['admin', 'user', 'support'])
        end

        it {
          is_expected.to contain_exec('homer-app-db-init')
            .with(command: sensitive(db_init), creates: marker)
            .that_requires("File[#{webapp_json}]")
            .that_comes_before('Service[homer-app]')
        }

        it { is_expected.to contain_file(marker).that_requires('Exec[homer-app-db-init]') }
        it { is_expected.to contain_service('homer-app').with(ensure: 'running', enable: true).that_requires('Package[homer-app]') }
        it { is_expected.not_to contain_exec('homer-app-admin-password') }
        it { is_expected.to contain_file(login_json).with_ensure('absent') }
      end

      context 'with install_app and app_admin_password' do
        let(:params) { { install_app: true, app_admin_password: sensitive("it's new") } }
        let(:login_file) { catalogue.resource('File', login_json) }

        it { is_expected.to compile.with_all_deps }

        it 'writes the login body root-only, with the password out of the diff' do
          is_expected.to contain_file(login_json).with(owner: 'root', group: 'root', mode: '0600', show_diff: false).that_requires('Package[homer-app]')
          expect(login_file.sensitive_parameters).to include(:content)
          expect(JSON.parse(login_file[:content])).to eq('username' => 'admin', 'password' => "it's new")
        end

        it { is_expected.to contain_file(check).with(mode: '0755', source: 'puppet:///modules/homer/homer-app-login-check') }

        it {
          is_expected.to contain_exec('homer-app-admin-password')
            .with(
              command: sensitive("homer-app -update-ui-user=admin -update-ui-password=it\\'s\\ new -webapp-config-path=/usr/local/homer/etc"),
              unless: "#{check} http://127.0.0.1:9080/api/v3/auth #{login_json}",
            )
            .that_requires(["File[#{login_json}]", "File[#{check}]", 'Service[homer-app]'])
        }
      end

      context 'with app_admin_password, another admin user and http_settings' do
        let(:params) do
          {
            install_app: true, app_admin_user: 'root-ui', app_admin_password: 'pw',
            app_settings: { 'http_settings' => { 'host' => '192.0.2.5', 'port' => 8443 } }
          }
        end

        it { is_expected.to contain_exec('homer-app-admin-password').with_unless("#{check} http://192.0.2.5:8443/api/v3/auth #{login_json}") }
        it { is_expected.to contain_exec('homer-app-admin-password').with_command(sensitive(%r{-update-ui-user=root-ui -update-ui-password=pw })) }
      end

      context 'with app_admin_password and no http_settings host or port' do
        let(:params) { { install_app: true, app_admin_password: 'pw', app_settings: {} } }

        it { is_expected.to contain_exec('homer-app-admin-password').with_unless("#{check} http://127.0.0.1:9080/api/v3/auth #{login_json}") }
      end

      context 'with install_app and passwords that need shell quoting' do
        let(:params) { { install_app: true, db_password: sensitive("it's secret"), db_admin_password: sensitive('p@ss word') } }

        it {
          is_expected.to contain_exec('homer-app-db-init').with_command(
            sensitive(%r{-database-root-password=p@ss\\ word .*-database-homer-password=it\\'s\\ secret }),
          )
        }

        it { expect(webapp['database_config']['pass']).to eq("it's secret") }
      end

      context 'with install_app and app_settings' do
        let(:params) { { install_app: true, app_settings: { 'http_settings' => { 'port' => 8080 }, 'database_config' => { 'user' => 'ignored' } } } }

        it { expect(webapp['http_settings']).to eq('port' => 8080) }
        it { expect(webapp['database_config']['user']).to eq('homer_user') }
      end

      context 'with install_app and app_db_init => false' do
        let(:params) { { install_app: true, app_db_init: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_exec('homer-app-db-init') }
        it { is_expected.not_to contain_file(marker) }
      end

      context 'with install_agent => true' do
        let(:params) { { install_agent: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify').with_ensure('installed') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::agent]') }
        it { is_expected.to contain_file('/etc/systemd/system/heplify.service.d').with_ensure('directory') }
        it { is_expected.to contain_file(dropin).that_notifies('Exec[homer-agent-systemd-daemon-reload]') }
        it { is_expected.to contain_file(dropin).with_content(%r{^ExecStart=\n}) }
        it { is_expected.to contain_file(dropin).with_content(%r{^ExecStart=/usr/local/bin/heplify -i any -hs 127\.0\.0\.1:9060 -m SIPRTCP$}) }

        # The package's own unit is left alone.
        it { is_expected.not_to contain_file('/etc/systemd/system/heplify.service') }

        it {
          is_expected.to contain_service('heplify')
            .with(ensure: 'running', enable: true)
            .that_requires('Package[heplify]')
            .that_subscribes_to(["File[#{dropin}]", 'Exec[homer-agent-systemd-daemon-reload]'])
        }
      end

      context 'with agent settings' do
        let(:params) { { install_agent: true, agent_interface: 'eth1', agent_hep_server: '10.0.0.5:9060,10.0.0.6:9060', agent_capture_mode: 'SIP', agent_options: ['-hi', '2002'] } }

        it { is_expected.to contain_file(dropin).with_content(%r{^ExecStart=/usr/local/bin/heplify -i eth1 -hs 10\.0\.0\.5:9060,10\.0\.0\.6:9060 -m SIP -hi 2002$}) }
      end

      context 'with an agent option containing whitespace' do
        let(:params) { { install_agent: true, agent_options: ['-hi 2002'] } }

        it { is_expected.to compile.and_raise_error(%r{agent_options}) }
      end

      context 'with everything installed' do
        let(:params) { { install_server: true, install_app: true, install_agent: true } }

        it { is_expected.to compile.with_all_deps }
      end

      context 'with manage_repo => false' do
        let(:params) { { manage_repo: false, install_server: true, install_app: true, install_agent: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_apt__source('sipcapture_official') }
        it { is_expected.not_to contain_class('apt::update') }
      end

      context 'with repo_architectures' do
        let(:params) { { repo_architectures: ['amd64', 'arm64'] } }

        it { is_expected.to contain_apt__source('sipcapture_official').with_architecture('amd64,arm64') }
      end

      context 'with repo_config replacing the default source' do
        let(:params) do
          {
            install_server: true,
            repo_config: { 'apt::source' => { 'local_mirror' => { 'location' => 'https://mirror.example.com/sipcapture/', 'release' => 'stable' } } },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_apt__source('local_mirror').with_location('https://mirror.example.com/sipcapture/') }
        it { is_expected.not_to contain_apt__source('sipcapture_official') }
      end

      context 'with configs' do
        let(:params) do
          {
            configs: { '/usr/local/homer/tls/cert.pem' => { 'content' => 'CERT' } },
            configs_defaults: { 'ensure' => 'file', 'mode' => '0600' },
          }
        end

        it { is_expected.to contain_file('/usr/local/homer/tls/cert.pem').with(ensure: 'file', mode: '0600', content: 'CERT') }
      end

      context 'with package providers' do
        let(:params) { { install_server: true, install_app: true, install_agent: true, server_package_provider: 'apt', app_package_provider: 'apt', agent_package_provider: 'apt' } }

        it { is_expected.to contain_package('heplify-server').with_provider('apt') }
        it { is_expected.to contain_package('homer-app').with_provider('apt') }
        it { is_expected.to contain_package('heplify').with_provider('apt') }
      end

      context 'with settings from Hiera' do
        let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
        let(:params) { { install_server: true, install_app: true } }

        it { is_expected.to contain_file(server_toml).with_content(%r{^PromAddr = "127\.0\.0\.1:9096"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBShema = "homer7"$}) }
        it { is_expected.to contain_file(server_toml).with_content(%r{^DBPass = "from-hiera"$}) }
        it { expect(webapp['http_settings']).to include('port' => 8080, 'root' => '/usr/local/homer/dist') }
        it { is_expected.to contain_exec('homer-app-db-init').with_command(sensitive(%r{-database-root-password=pg-from-hiera })) }
        it { is_expected.to contain_exec('homer-app-admin-password').with_command(sensitive(%r{-update-ui-password=ui-from-hiera })) }
      end
    end
  end

  context 'on RedHat 9' do
    let(:facts) { on_supported_os(supported_os: [{ 'operatingsystem' => 'RedHat', 'operatingsystemrelease' => ['9'] }]).values.first }

    context 'with manage_repo => true' do
      it { is_expected.to compile.and_raise_error(%r{manage_repo only sets up QXIP's APT repository, and this is a RedHat system}) }
    end

    context 'with manage_repo => false' do
      let(:params) { { manage_repo: false, install_server: true, install_app: true, install_agent: true } }

      it { is_expected.to compile.with_all_deps }
    end
  end
end
