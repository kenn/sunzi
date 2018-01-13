require 'net/ssh'

module Sunzi
  class Endpoint
    attr_reader :user, :host, :port

    def initialize(input)
      input.match(/(.*@)?(.*?)(:.*)?$/)
      # Load ssh config if it exists
      ssh = Net::SSH::Config.for($2)

      @user = $1 && $1.delete('@') || ssh[:user] || 'root'
      @host = ssh[:host_name] || $2
      @port = $3 && $3.delete(':') || ssh[:port] && ssh[:port].to_s || '22'
    end
  end
end
