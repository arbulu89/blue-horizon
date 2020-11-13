# frozen_string_literal: true

require 'rails_helper'

describe CustomHelpers do
  subject(:helper) { Class.new.include(described_class).new }

  describe 'plan_resources' do
    context 'with empty input' do
      let!(:input) { [nil, '', {}, []] }

      it 'returns an empty hash' do
        input.each do |i|
          expect(helper.plan_resources(i)).to eq({})
        end
      end
    end
  end

  describe 'resource_icon' do
    resource_type_icon_map = {
      'azurerm_security_group'                                     => 'security',
      'azurerm_subnet_network_security_group_association'          => 'security',
      'azurerm_network_security_rule'                              => 'network_policy',
      'azurerm_subnet'                                             => 'network',
      'azurerm_network_interface'                                  => 'ip',
      'azurerm_public_ip'                                          => 'ip',
      'azurerm_virtual_machine'                                    => 'node',
      'tls_private_key'                                            => 'vpn_key',
      'azurerm_storage_account'                                    => 'storage',
      'azurerm_resource_group'                                     => 'namespace',
      'azurerm_subnet_route_table_association'                     => 'abstract',
      'azurerm_network_interface_backend_address_pool_association' => 'abstract',
      'foobar'                                                     => 'abstract'
    }

    resource_type_icon_map.each do |type, icon|
      it "returns the '#{icon}' icon for the '#{type}' type" do
        resource = { 'type' => type }
        expect(helper.resource_icon(resource)).to eq icon
      end
    end
  end
end
