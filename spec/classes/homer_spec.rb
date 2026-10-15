# frozen_string_literal: true

require 'spec_helper'

describe 'homer' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:codename) { os_facts[:os]['distro']['codename'] }

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
        it { is_expected.not_to contain_apt__key('Add key: 8AE3BC335C18EB6F from Apt::Source sipcapture_official') }
        it { is_expected.to contain_apt__keyring('homer-repo.gpg') }
      end

      context 'with install_server => true' do
        let(:params) { { install_server: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify-server').with_ensure('installed') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::server]') }

        # The heplify-server package's unit reads /etc/heplify-server.toml.
        it { is_expected.to contain_file('/etc/heplify-server.toml').that_requires('Package[heplify-server]').that_notifies('Service[heplify-server]') }
        it { is_expected.to contain_file('/etc/heplify-server.toml').with_content(%r{^DBUser = "homer_user"$}) }
        it { is_expected.to contain_file('/etc/heplify-server.toml').with_content(%r{^DBPass = "homer_password"$}) }
        it { is_expected.to contain_file('/etc/heplify-server.toml').with_content(%r{^Config = "/etc/heplify-server.toml"$}) }
        it { is_expected.to contain_service('heplify-server').with(ensure: 'running', enable: true).that_requires('Package[heplify-server]') }
      end

      context 'with install_app => true' do
        let(:params) { { install_app: true } }
        let(:db_init) do
          'homer-app -initialize_db -database-root-user=postgres -database-root-password=postgresql_password ' \
            '-database-host=127.0.0.1 -database-homer-user=homer_user -database-homer-password=homer_password ' \
            '-webapp-config-path=/usr/local/homer/etc'
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('homer-app').with_ensure('present') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::app]') }
        it { is_expected.to contain_file('/usr/local/homer/etc/webapp_config.json').with_content(%r{"pass": "homer_password"}) }

        it {
          is_expected.to contain_exec('homer-app-db-init')
            .with(command: sensitive(db_init), creates: '/usr/local/homer/.homerapp-db-initialized')
            .that_requires('File[/usr/local/homer/etc/webapp_config.json]')
            .that_comes_before('Service[homer-app]')
        }

        it { is_expected.to contain_file('/usr/local/homer/.homerapp-db-initialized').that_requires('Exec[homer-app-db-init]') }
        it { is_expected.to contain_service('homer-app').with(ensure: 'running', enable: true) }
      end

      context 'with install_app and passwords that need shell quoting' do
        let(:params) { { install_app: true, db_password: "it's secret", db_admin_password: 'p@ss word' } }

        it {
          is_expected.to contain_exec('homer-app-db-init').with_command(
            sensitive(%r{-database-root-password=p@ss\\ word .*-database-homer-password=it\\'s\\ secret }),
          )
        }
      end

      context 'with install_agent => true' do
        let(:params) { { install_agent: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify').with_ensure('installed') }
        it { is_expected.to contain_class('apt::update').that_comes_before('Class[homer::agent]') }

        # Written after the package, which ships its own copy of this unit.
        it {
          is_expected.to contain_file('/etc/systemd/system/heplify.service')
            .that_requires('Package[heplify]')
            .that_notifies(['Exec[homer-systemd-reload]', 'Service[heplify]'])
        }

        it { is_expected.to contain_file('/etc/systemd/system/heplify.service').with_content(%r{^ExecStart=/usr/local/bin/heplify -i enp1s0 -hs 127\.0\.0\.1:9060 -m SIPRTCP$}) }
        it { is_expected.to contain_service('heplify').with(ensure: 'running', enable: true) }
      end

      context 'with everything installed and no PostgreSQL class in the catalog' do
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
            repo_config: {
              'apt::source' => {
                'local_mirror' => { 'location' => 'https://mirror.example.com/sipcapture/', 'release' => 'stable' },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_apt__source('local_mirror').with_location('https://mirror.example.com/sipcapture/') }
        it { is_expected.not_to contain_apt__source('sipcapture_official') }
      end

      context 'with package providers' do
        let(:params) { { install_server: true, install_app: true, install_agent: true, server_package_provider: 'apt', app_package_provider: 'apt', agent_package_provider: 'apt' } }

        it { is_expected.to contain_package('heplify-server').with_provider('apt') }
        it { is_expected.to contain_package('homer-app').with_provider('apt') }
        it { is_expected.to contain_package('heplify').with_provider('apt') }
      end
    end
  end
end
