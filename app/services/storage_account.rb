# frozen_string_literal: true

require 'net/http'
require 'net/https'
require 'uri'
require 'base64'

# Class to wrap all storage account operations
class StorageAccount
  include I18n

  X_MS_VERSION = '2018-11-09'

  def check_resource(account, key, resource)
    # The callas are based on:
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-file-metadata
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-directory-metadata
    if File.extname(resource).present?
      # The resource is a file
      parameters = "#{resource}?comp=metadata"
      resource = "#{resource}?comp=metadata"
    else
      # The resource is a folder
      parameters = resource
      resource = "#{resource}?restype=directory"
    end

    res = request(account, key, resource, parameters)

    return true if res.is_a?(Net::HTTPOK)

    output = if res.is_a?(Net::HTTPResponse)
      res.message
    else
      res
    end

    return {
      error: {
        message: 'Error checking the storage account data',
        output:  "#{I18n.t('storage_account_error')}<br><br>#{output}"
      }
    }
  end

  private

  def request(account, key, resource, parameters)
    # Based on https://docs.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key
    Rails.logger.debug 'New storage account request...'
    return "Invalid key format (check if the key finishes with '==')." unless key =~ /.*==/

    url = "https://#{account}.file.core.windows.net/#{resource}"
    xm_ms_date = Time.current.strftime('%a, %d %b %Y %H:%M:%S GMT')
    canonicalized_resources = "/#{account}/#{parameters}"
    canonicalized_headers = "x-ms-date:#{xm_ms_date}\nx-ms-version:#{X_MS_VERSION}"
    string_to_sign = "GET\n\n\n\n#{canonicalized_headers}\n#{canonicalized_resources}"
    Rails.logger.debug "String to sign: #{string_to_sign}"

    digest = OpenSSL::Digest.new('sha256')
    signature = Base64.encode64(
      OpenSSL::HMAC.digest(digest, Base64.decode64(key), string_to_sign.encode('utf-8'))
    ).strip

    uri = URI.parse(url)

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    req = Net::HTTP::Get.new(uri)
    req['x-ms-date'] = xm_ms_date
    req['x-ms-version'] = X_MS_VERSION
    req['Authorization'] = "SharedKeyLite #{account}:#{signature}"

    https.request(req)
  rescue SocketError => e
    Rails.logger.error "Error connecting to the storage account: #{e}"
    "#{e}."
  end
end
