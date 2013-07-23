require 'sunzi'
require 'net/ssh'
require 'test/unit'
require 'minitest/mock'

class TestCli < Test::Unit::TestCase
  def setup
    @cli = Sunzi::Cli.new
  end

  def test_parse_target
    Net::SSH::Config.stub(:for, {}) do
      assert_equal ['user', 'example.com', '2222'], @cli.parse_target('user@example.com:2222')
      assert_equal ['root', 'example.com', '2222'], @cli.parse_target('example.com:2222')
      assert_equal ['user', 'example.com', '22'],   @cli.parse_target('user@example.com')
      assert_equal ['root', 'example.com', '22'],   @cli.parse_target('example.com')
      assert_equal ['root', '192.168.0.1', '22'],   @cli.parse_target('192.168.0.1')
    end
  end

  def test_parse_target_with_ssh_config
    dummy_config = lambda do |host|
      if host == 'example.com'
        {
          :host_name => "buzz.example.com",
          :user => "foobar",
          :port => 2222,
          :keys => ["my_id_rsa"]
        }
      else
        {}
      end
    end

    Net::SSH::Config.stub(:for, dummy_config) do
      assert_equal ['foobar', 'buzz.example.com', '2222'], @cli.parse_target('example.com')
      assert_equal ['foobar', 'buzz.example.com', '8080'], @cli.parse_target('example.com:8080')
      assert_equal ['piyo', 'buzz.example.com', '2222'], @cli.parse_target('piyo@example.com')
      assert_equal ['piyo', 'buzz.example.com', '8080'], @cli.parse_target('piyo@example.com:8080')
      assert_equal ['root', '192.168.0.1', '22'], @cli.parse_target('192.168.0.1')
    end
  end

  def test_create
    @cli.create 'sandbox'
    assert File.exist?('sandbox/sunzi.yml')
    FileUtils.rm_rf 'sandbox'
  end
end
