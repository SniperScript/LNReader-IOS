Pod::Spec.new do |s|
  s.name           = 'NativeBackgroundTasks'
  s.version        = '1.0.0'
  s.summary        = 'NativeBackgroundTasks module'
  s.description    = 'NativeBackgroundTasks module'
  s.license        = 'MIT'
  s.author         = ''
  s.homepage       = 'https://github.com/LNReader/lnreader'
  s.platforms      = { :ios => '15.5', :tvos => '15.5' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.source_files = "**/*.{h,m,swift}"
end
