Pod::Spec.new do |s|
  s.name = 'TooolsPermissionScope'
  s.version = '1.0.2'
  s.license = 'MIT'
  s.summary = 'A Periscope-inspired way to ask for iOS permissions'
  s.homepage = 'https://github.com/mememto/PermissionScope'
  s.social_media_url = 'https://twitter.com/objctoswift'
  s.authors = { "Luciano Rodriguez" => 'luciano@toools.es' }
  s.source = { :git => 'https://github.com/mememto/PermissionScope.git', :tag => s.version }

  s.ios.deployment_target = '10.0'

  s.source_files = 'TooolsPermissionScope/*.swift'

  s.requires_arc = false
end
