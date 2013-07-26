# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :minitest
Hoe.plugin :git

hoe = Hoe.spec 'rdoc-browser' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  rdoc_locations <<
  'docs.seattlerb.org:/data/www/docs.seattlerb.org/rdoc-browser/'

  self.readme_file = 'README.rdoc'
end

hoe.test_prelude = 'gem "minitest", "~> 4.0"'

# vim: syntax=ruby
