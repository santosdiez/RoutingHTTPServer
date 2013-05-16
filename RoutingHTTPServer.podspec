Pod::Spec.new do |s|
  s.name = 'RoutingHTTPServer'
  s.version = '0.0.1'
  s.summary = 'A routing API for CocoaHTTPServer.'
  s.homepage = 'https://github.com/santosdiez/RoutingHTTPServer'
  s.license = 'MIT'
  s.author = 'Matt Stevens'
  s.source = { :git => 'https://github.com/santosdiez/RoutingHTTPServer.git' }
  s.source_files = 'source/*.{h,m}'
  s.requires_arc = true
  s.dependency 'CocoaHTTPServer', '~> 2.3'
end