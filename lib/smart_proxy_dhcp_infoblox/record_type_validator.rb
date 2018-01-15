module ::Proxy::DHCP::Infoblox
  class RecordTypeValidator < ::Proxy::PluginValidators::Base
    def validate!(settings)
      return true if ['host', 'fixedaddress'].include?(settings[:record_type])
      raise ::Proxy::Error::ConfigurationError, "Setting 'record_type' can be set to either 'host' or 'fixedaddress'"
    end
  end
end
