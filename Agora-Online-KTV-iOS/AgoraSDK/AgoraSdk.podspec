#
# Be sure to run `pod lib lint AgoraAutoKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AgoraSdk'
  s.version          = '0.1.0'
  s.summary          = 'A short description of AgoraSdk.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/lienbao/AgoraSdk'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'lienbao' => 'lienbao@agora.io' }
  s.source           = { :git => 'https://github.com/lienbao/AgoraSdk.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'
#  s.static_framework = true
  s.libraries   = 'z', 'resolv.9', 'c++'
  s.frameworks = 'UIKit','SystemConfiguration','CoreLocation','Foundation','CoreML','VideoToolbox','CoreMedia','CoreAudio','Accelerate','CoreTelephony'
  s.vendored_frameworks ='3.4.200/Libs/*.framework','3.4.200/RtmKit/*.framework'
  s.vendored_libraries = '3.4.200/Libs/*.a'
    
end
