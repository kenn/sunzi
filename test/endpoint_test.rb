require 'test_helper'

class TestEndpoint < Minitest::Test
  def deconstruct(e)
    [e.user, e.host, e.port]
  end

  def test_parse_target
    assert_equal ['user', 'example.com', '2222'], deconstruct(Sunzi::Endpoint.new('user@example.com:2222'))
    assert_equal ['root', 'example.com', '2222'], deconstruct(Sunzi::Endpoint.new('example.com:2222'))
    assert_equal ['user', 'example.com', '22'],   deconstruct(Sunzi::Endpoint.new('user@example.com'))
    assert_equal ['root', 'example.com', '22'],   deconstruct(Sunzi::Endpoint.new('example.com'))
    assert_equal ['root', '192.168.0.1', '22'],   deconstruct(Sunzi::Endpoint.new('192.168.0.1'))
  end

  def test_parse_target_with_ssh_config
    ssh_config = lambda do |host|
      if host == 'example.com'
        { host_name: 'buzz.example.com', user: 'foobar', port: 2222 }
      else
        {}
      end
    end

    Net::SSH::Config.singleton_class.alias_method :original_for, :for
    Net::SSH::Config.define_singleton_method(:for) { |host| ssh_config.call(host) }

    assert_equal ['foobar', 'buzz.example.com', '2222'],  deconstruct(Sunzi::Endpoint.new('example.com'))
    assert_equal ['foobar', 'buzz.example.com', '8080'],  deconstruct(Sunzi::Endpoint.new('example.com:8080'))
    assert_equal ['piyo', 'buzz.example.com', '2222'],    deconstruct(Sunzi::Endpoint.new('piyo@example.com'))
    assert_equal ['piyo', 'buzz.example.com', '8080'],    deconstruct(Sunzi::Endpoint.new('piyo@example.com:8080'))
    assert_equal ['root', '192.168.0.1', '22'],           deconstruct(Sunzi::Endpoint.new('192.168.0.1'))
  ensure
    Net::SSH::Config.singleton_class.undef_method :for
    Net::SSH::Config.singleton_class.alias_method :for, :original_for
    Net::SSH::Config.singleton_class.undef_method :original_for
  end
end
