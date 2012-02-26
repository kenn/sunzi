module Sunzi
  class Dependency
    def self.all
      {
        'linode' => {
          :require => 'linode',
          :version => '>= 0.7.7',
        },
        'highline' => {
          :require => 'highline',
          :version => '>= 1.6.11',
        },
        'route53' => {
          :require => 'route53',
          :version => '>= 0.2.1',
        },
      }
    end

    def self.load(name)
      begin
        gem(name, all[name][:version])
        require(all[name][:require])
      rescue LoadError
        puts <<-EOS
Dependency missing: #{name}
To install the gem, issue the following command:

    gem install #{name} -v '#{all[name][:version]}'

Please try again after installing the missing dependency.
        EOS
        exit 1
      end
    end

  end
end
