# frozen_string_literal: true

require 'rails_helper'

describe 'dashboards', type: :feature do
  context 'with customized top menu items' do
    let(:ha_cluster_url) { '/dashboards/ha_cluster' }
    let(:main_tenant_url) { '/dashboards/main_tenant' }
    let(:systemdb_url) { '/dashboards/systemdb' }
    let(:tuning_url) { '/dashboards/tuning' }

    before do
      top_menu_data = JSON.parse([
        {
          key:     'monitor',
          url:     ha_cluster_url,
          sidebar: {
            ha_cluster: 'cluster-iframe-%{data}',
            hana_dbs:   {
              main_tenant: 'prd-iframe',
              systemdb:    'systemd-iframe'
            }
          }
        }.with_indifferent_access,
        {
          key:     'tuning',
          url:     tuning_url,
          sidebar: {
            tuning: 'tuning'
          }
        }.with_indifferent_access
      ].to_json,
        object_class: OpenStruct
      )

      Rails.configuration.x.top_menu_items = top_menu_data

      allow_any_instance_of(Terraform).to receive(:outputs).and_return(
        {
          data: 'iframe-data',
          sid:  'PRD'
        }
      )
    end

    after do
      Rails.configuration.x.top_menu_items = nil
    end

    it 'includes custom dashboards menu items' do
      visit(ha_cluster_url)

      submenu = find('a.submenu-item#monitor')

      expect(submenu).to have_content('Monitor')
      expect(submenu[:class]).to include('selected')
      expect(page).to have_link('Monitor', href: ha_cluster_url)

      nav = find('div.mm-navigation-container').find('div.nav-wrap')
      dropdown = nav.find('li.menu-dropdown')

      expect(nav).to have_link('HA cluster', href: ha_cluster_url)
      expect(dropdown).to have_link('PRD', href: main_tenant_url)
      expect(dropdown).to have_link('SYSTEMDB', href: systemdb_url)

      expect(nav).not_to have_link('Tuning', href: tuning_url)

      iframe = find('div.grafana-container').find('iframe')
      expect(iframe[:src]).to match('cluster-iframe-iframe-data')
    end

    it 'selects correct menu' do
      visit(tuning_url)

      submenu = find('a.submenu-item#tuning')

      expect(submenu).to have_content('Tuning')
      expect(submenu[:class]).to include('selected')
    end

    it 'redirects if dashboard is not found' do
      visit('/dashboards/error')

      submenu = find('a.submenu-item#monitor')
      expect(submenu[:class]).to include('selected')

      nav = find('div.mm-navigation-container').find('div.nav-wrap')
      expect(nav).to have_link('HA cluster', href: ha_cluster_url)
    end
  end
end
