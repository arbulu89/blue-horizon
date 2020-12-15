# frozen_string_literal: true

require 'rails_helper'

describe 'resources', type: :feature do
  let(:mock_template) { 'foo_%{greeting}_bar' }
  let(:expected_output) { 'foo_Hello, World._bar' }

  before do
    I18n.backend.store_translations(:en, resources_content: mock_template)
  end

  context 'with configured output' do
    before do
      Rails.configuration.x.top_menu_items = [
        {
          key:     'resources',
          url:     '/resources',
          sidebar: {
            resource: '/resources'
          }
        }.with_indifferent_access
      ]

      allow_any_instance_of(Terraform).to receive(:outputs).and_return(
        {
          greeting:                'Hello, World.',
          admin_user:              'myuser',
          ssh_authorized_key_file: 'id_rsa.pub',
          hana_ha_enabled:         true,
          bastion_ip:              '1.2.3.4',
          hana_ips:                '11.22.33.44,55.66.77.88',
          iscsi_ip:                '4.3.2.1',
          monitoring_ip:           '5.6.7.8'
        }
      )

      visit('/resources')
    end

    it 'shows the resources content rendered in markdown' do
      expect(page).to have_content(expected_output)
    end

    it 'includes bastion the ssh command' do
      command = 'ssh myuser@1.2.3.4 -i id_rsa'
      expect(find('input#bastion', visible: false).value).to eq command
    end

    it 'includes the ssh commands' do
      data = {
        hana_0:     '11.22.33.44',
        hana_1:     '55.66.77.88',
        iscsi:      '4.3.2.1',
        monitoring: '5.6.7.8'
      }

      data.each do |key, ip|
        command = 'ssh -o ProxyCommand="ssh -W %h:%p myuser@1.2.3.4'\
        ' -i id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"'\
        " myuser@#{ip} -i"\
        ' id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
        expect(find("input##{key}", visible: false).value).to eq command
      end
    end
  end
end
