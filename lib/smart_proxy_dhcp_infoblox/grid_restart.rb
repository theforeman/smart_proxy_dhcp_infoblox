module ::Proxy::DHCP::Infoblox
  class GridRestart
    MAX_ATTEMPTS = 5

    include ::Proxy::Log
    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def try_restart
      logger.info 'Restarting Infoblox Grid'

      delay = Proxy::DHCP::Infoblox::Plugin.settings.wait_after_restart.to_i
      MAX_ATTEMPTS.times do |tries|
        if restart
          if delay > 0
            logger.info "Starting post-restart delay of #{delay} seconds..."
            sleep delay
            logger.debug "Post-restart delay done"
          end
          return
        end
        sleep tries
      end

      logger.warn 'Restarting Infoblox Grid failed, giving up'
      false
    end

    private

    def restart
      (@grid ||= ::Infoblox::Grid.get(@connection).first).restartservices
      true
    rescue Exception => e
      logger.warn "Error during Grid restart: #{e}"
      false
    end
  end
end
