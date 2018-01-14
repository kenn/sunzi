require 'test_helper'

class TestCommand < Minitest::Test
  def setup
    @pwd = Dir.pwd
    Dir.chdir Sunzi::GemRoot.join('test/project')

    @command = Sunzi::Command.new
  end

  def teardown
    Dir.chdir @pwd
    FileUtils.rm_rf Sunzi::GemRoot.join('test/project/compiled')
    FileUtils.rm_rf Sunzi::GemRoot.join('test/project/sandbox')
  end

  def test_create
    assert_output(/sandbox/) do
      @command.create 'sandbox'
    end
    assert Dir.exist?('sandbox/files')
    assert Dir.exist?('sandbox/recipes')
    assert Dir.exist?('sandbox/roles')
    assert File.exist?('sandbox/recipes/sunzi.sh')
    assert File.exist?('sandbox/roles/db.sh')
    assert File.exist?('sandbox/roles/web.sh')
    assert File.exist?('sandbox/install.sh')
    assert File.exist?('sandbox/sunzi.yml')
  end

  def test_compile
    assert_output(/compiled/) do
      @command.compile('db')
    end
    assert Dir.exist?('compiled/files')
    assert Dir.exist?('compiled/files/nginx')
    assert Dir.exist?('compiled/recipes')
    assert Dir.exist?('compiled/roles')
    assert File.exist?('compiled/files/nginx/nginx.conf')
    assert File.exist?('compiled/recipes/nginx.sh')
    assert File.exist?('compiled/recipes/rvm.sh')
    assert File.exist?('compiled/roles/db.sh')
    assert File.exist?('compiled/install.sh')
    assert_equal File.read('compiled/install.sh'), "\# world\n\# db.sh"
  end
end
