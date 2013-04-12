module Sunzi
  class Dependency
    def self.all
      {
        'linode' =>   { :require => 'linode',   :version => '>= 0.7.9' },
        'highline' => { :require => 'highline', :version => '>= 1.6.11'},
        'route53' =>  { :require => 'route53',  :version => '>= 0.2.1' },
        'digital_ocean' =>  { :require => 'digital_ocean',  :version => '>= 1.0.0' },
      }
    end

    def self.load(name)
      begin
        gem(name, all[name][:version])
        require(all[name][:require])
      rescue LoadError
        if $!.to_s =~ /Gemfile/
          Logger.error <<-EOS
Dependency missing: #{name}
Add this line to your application's Gemfile.

    gem '#{name}', '#{all[name][:version]}'

Please try again after running "bundle install".
          EOS
        else
          Logger.error <<-EOS
Dependency missing: #{name}
To install the gem, issue the following command:

    gem install #{name} -v '#{all[name][:version]}'

Please try again after installing the missing dependency.
          EOS
        end
        abort
      end
    end
  end
end
