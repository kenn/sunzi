#!/usr/bin/env ruby

require 'yaml'
hash = YAML.load(File.read('attributes.yml'))

require 'fileutils'
FileUtils.mkdir_p('../there/attributes')

hash.each do |key, value|
  File.open("../there/attributes/#{key}", 'w'){|file| file.write(value) }
end
