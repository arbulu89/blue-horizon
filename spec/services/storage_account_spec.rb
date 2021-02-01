# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
require 'net/http'
require 'net/https'

RSpec.describe StorageAccount, type: :service do
  let(:storage_account_instance) { described_class.new }

  before do
    I18n.backend.store_translations(:en, storage_account_error: 'storage account error')
  end

  it 'send a file request' do
    net_http_resp = Net::HTTPOK.new(1.0, 200, 'OK')
    allow(storage_account_instance).to receive(:request).and_return(net_http_resp)

    result = storage_account_instance.check_resource('account', 'key', 'file.txt')

    expect(result).to eq(true)

    expect(storage_account_instance).to(
      have_received(:request)
        .with(
          'account',
          'key',
          'file.txt?comp=metadata',
          'file.txt?comp=metadata'
        )
    )
  end

  it 'send a directory request' do
    net_http_resp = Net::HTTPOK.new(1.0, 200, 'OK')
    allow(storage_account_instance).to receive(:request).and_return(net_http_resp)

    result = storage_account_instance.check_resource('account', 'key', 'folder')

    expect(result).to eq(true)

    expect(storage_account_instance).to(
      have_received(:request)
        .with(
          'account',
          'key',
          'folder?restype=directory',
          'folder'
        )
    )
  end

  it 'send an invalid request' do
    net_http_resp = Net::HTTPResponse.new(1.0, 404, 'Error')
    allow(storage_account_instance).to receive(:request).and_return(net_http_resp)

    result = storage_account_instance.check_resource('account', 'key', 'folder')

    expect(result).to eq(
      {
        error: {
          message: 'Error checking the storage account data',
          output:  'storage account error<br><br>Error'
        }
      }
    )

    expect(storage_account_instance).to(
      have_received(:request)
        .with(
          'account',
          'key',
          'folder?restype=directory',
          'folder'
        )
    )
  end

  it 'send request with invalid socket' do
    allow(storage_account_instance).to receive(:request).and_return('socket error')

    result = storage_account_instance.check_resource('account', 'key', 'folder')

    expect(result).to eq(
      {
        error: {
          message: 'Error checking the storage account data',
          output:  'storage account error<br><br>socket error'
        }
      }
    )

    expect(storage_account_instance).to(
      have_received(:request)
        .with(
          'account',
          'key',
          'folder?restype=directory',
          'folder'
        )
    )
  end

  context 'with storage account requests' do
    let!(:date) { Time.current.strftime('%a, %d %b %Y %H:%M:%S GMT') }
    let!(:string_to_sign) { "GET\n\n\n\nx-ms-date:#{date}\nx-ms-version:2018-11-09\n/account/?comp=file" }
    let!(:signature) do
      Base64.encode64(
        OpenSSL::HMAC.digest(
          OpenSSL::Digest.new('sha256'), Base64.decode64('key'), string_to_sign.encode('utf-8')
        )
      ).strip
    end
    let!(:storage_request) do
      stub_request(:get, 'https://account.file.core.windows.net/file')
        .with(
          headers: {
            'Accept'          => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'   => "SharedKeyLite account:#{signature}",
            'Host'            => 'account.file.core.windows.net',
            'User-Agent'      => 'Ruby',
            'X-Ms-Date'       => date,
            'X-Ms-Version'    => '2018-11-09'
          }
        ).to_return(body: 'OK')
    end

    it 'creates a request signature correctly' do
      storage_account_instance.send(
        :request, 'account', 'key==', 'file', '?comp=file'
      )

      expect(storage_request).to have_been_requested
    end

    it 'creates a request signature with invalid key' do
      response = storage_account_instance.send(
        :request, 'account', 'key', 'file', '?comp=file'
      )
      expect(response).to match('Invalid key format (check if the key finishes with \'==\').')
    end

    it 'creates a request signature with socket error' do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(SocketError, 'error')

      response = storage_account_instance.send(
        :request, 'account', 'key==', 'file', '?comp=file'
      )
      expect(response).to match('error.')
    end
  end
end
