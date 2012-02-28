require 'test/unit'
require '../lib/sunzi'

class TestCli < Test::Unit::TestCase
  def setup
    @cli = Sunzi::Cli.new
  end

  def test_parse_target
    assert_equal ['user', 'example.com', '2222'], @cli.parse_target('user@example.com:2222')
    assert_equal ['root', 'example.com', '2222'], @cli.parse_target('example.com:2222')
    assert_equal ['user', 'example.com', '22'],   @cli.parse_target('user@example.com')
    assert_equal ['root', 'example.com', '22'],   @cli.parse_target('example.com')
    assert_equal ['root', '192.168.0.1', '22'],   @cli.parse_target('192.168.0.1')
  end

  def test_create
    @cli.create 'sandbox'
    assert File.exist?('sandbox/sunzi.yml')
    FileUtils.rm_rf 'sandbox'
  end
end
