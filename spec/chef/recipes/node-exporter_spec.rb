require 'chef_helper'

describe 'gitlab::node-exporter' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when node-exporter is enabled' do
    let(:config_template) { chef_run.template('/var/log/gitlab/node-exporter/config') }

    before do
      stub_gitlab_rb(
        node_exporter: { enable: true }
      )
    end

    it_behaves_like 'enabled runit service', 'node-exporter', 'root', 'root'

    it 'populates the files with expected configuration' do
      expect(config_template).to notify('ruby_block[reload node-exporter svlogd configuration]')

      expect(chef_run).to render_file('/opt/gitlab/sv/node-exporter/run')
        .with_content { |content|
          expect(content).to match(/exec chpst -P/)
          expect(content).to match(/\/opt\/gitlab\/embedded\/bin\/node_exporter/)
          expect(content).to match(/\/textfile_collector/)
        }

      expect(chef_run).to render_file('/opt/gitlab/sv/node-exporter/log/run')
        .with_content(/exec svlogd -tt \/var\/log\/gitlab\/node-exporter/)
    end

    it 'creates default set of directories' do
      expect(chef_run).to create_directory('/var/log/gitlab/node-exporter').with(
        owner: 'gitlab-prometheus',
        group: nil,
        mode: '0700'
      )
      expect(chef_run).to create_directory('/var/opt/gitlab/node-exporter/textfile_collector').with(
        owner: 'gitlab-prometheus',
        group: nil,
        mode: '0755'
      )
    end
  end

  context 'when node-exporter is enabled and prometheus is disabled' do
    before do
      stub_gitlab_rb(
        prometheus: { enable: false },
        node_exporter: { enable: true }
      )
    end

    it 'should create the gitlab-prometheus account if prometheus is disabled' do
      expect(chef_run).to create_user('gitlab-prometheus')
    end
  end

  context 'when log dir is changed' do
    before do
      stub_gitlab_rb(
        node_exporter: {
          log_directory: 'foo',
          enable: true
        }
      )
    end
    it 'populates the files with expected configuration' do
      expect(chef_run).to render_file('/opt/gitlab/sv/node-exporter/log/run')
        .with_content(/exec svlogd -tt foo/)
    end
  end
end
