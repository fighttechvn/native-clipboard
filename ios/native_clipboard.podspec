#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_clipboard.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_clipboard'
  s.version          = '0.1.0'
  s.summary          = 'Images on and off the system clipboard.'
  s.description      = <<-DESC
Read images off the system clipboard, and paste them into a text field.
                       DESC
  s.homepage         = 'https://github.com/fighttechvn/native-clipboard'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Fighttech' => 'dev@fighttech.vn' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # The pasteboard is not one of Apple's required reason APIs, so the manifest
  # declares no reasons and no tracking. It ships anyway: an app that has to
  # account for what its dependencies do can point at this one.
  s.resource_bundles = {'native_clipboard_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
