# frozen_string_literal: true

require 'rails_helper'

describe 'plan', type: :feature do
  before do
    copy_plan_fixture
    copy_sources
    Rails.configuration.x.override_views = true
  end

  it 'displays various sections' do
    visit plan_path

    expect(page).to have_selector '#plan'
    plan_block = find '#plan'

    # The following assertions are quite specific to the fixture used.
    # If you find having to change these too often, consider looking up
    # all the values dynamically from the plan

    expect(plan_block).to have_selector '.system-settings'
    expect(plan_block).to have_selector '.resource-group'
    expect(plan_block).to have_selector '.hana-nodes'
    expect(plan_block).to have_selector '.virtual-networks'
    expect(plan_block).to have_selector '.monitoring-server'
    expect(plan_block).to have_selector '.security-group'

    system_settings = plan_block.find '.system-settings'
    expect(system_settings).to have_text 'System identifier: PRD'
    expect(system_settings).to have_text 'Instance number: 00'
    expect(system_settings).to have_text 'Admin user: prdadm'
    expect(system_settings).to have_text 'Admin password: .Password1'

    resource_group = plan_block.find '.resource-group'
    expect(resource_group).to have_text 'Name: rg-ha-sap-test'
    expect(resource_group).to have_text 'Region: westeurope'

    hana_nodes = plan_block.find '.hana-nodes'
    expect(hana_nodes).to have_selector '.hana-node', count: 2
    hana_nodes.find_all('.hana-node').each_with_index do |hana_node, i|
      expect(hana_node).to have_text "Name: vmhana0#{i + 1}"
      expect(hana_node).to have_text 'Size: Standard_E8s_v3'
      expect(hana_node).to have_text "Private IP address: 10.74.1.1#{i}"
      expect(hana_node).to have_text 'OS Image: sles-sap-15-sp2'
      expect(hana_node).to have_selector '.disk', count: 7
      hana_node.find_all('.disk').each_with_index do |hana_disk, j|
        expect(hana_disk).to have_text "disk-hana0#{i + 1}-Data0#{j + 1} (128GB)"
      end
    end

    virtual_networks = plan_block.find '.virtual-networks'
    expect(virtual_networks).to have_selector '.network', count: 2
    networks = virtual_networks.find_all '.network'
    expect(networks[0]).to have_text 'Name: vnet-test'
    expect(networks[0]).to have_text 'Address range: 10.74.0.0/16'
    expect(networks[1]).to have_text 'Name: snet-test'
    expect(networks[1]).to have_text 'Address range: 10.74.1.0/24'

    bastion = plan_block.find '.bastion'
    expect(bastion).to have_text 'Name: vmbastion'
    expect(bastion).to have_text 'Size: Standard_B1s'
    expect(bastion).to have_text 'Private IP address: 10.74.2.5'
    expect(bastion).to have_text 'OS Image: sles-sap-15-sp2'

    monitoring_server = plan_block.find '.monitoring-server'
    expect(monitoring_server).to have_text 'Name: vmmonitoring'
    expect(monitoring_server).to have_text 'Size: Standard_D2s_v3'
    expect(monitoring_server).to have_text 'Private IP address: 10.74.1.5'
    expect(monitoring_server).to have_text 'OS Image: sles-sap-15-sp2'
    expect(monitoring_server).to have_selector '.disk', count: 1
    expect(monitoring_server.find('.disk')).to have_text 'disk-monitoring-Data01 (10GB)'

    security_group = plan_block.find '.security-group'
    expect(security_group).to have_text 'Name: nsg-test'
    expect(security_group).to have_selector '.rules .rule'

    iscsi_server = plan_block.find '.iscsi-server'
    expect(iscsi_server).to have_text 'Name: vmiscsisrv01'
    expect(iscsi_server).to have_text 'Size: Standard_D2s_v3'
    expect(iscsi_server).to have_text 'Private IP address: 10.74.1.4'
    expect(iscsi_server).to have_text 'OS Image: sles-sap-15-sp2'
    expect(iscsi_server).to have_selector '.disk', count: 1
    expect(iscsi_server.find('.disk')).to have_text 'disk-iscsisrv01-Data01 (10GB)'
  end
end
