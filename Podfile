# Uncomment this line to define a global platform for your project
platform :ios, '8.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'LNSimplePhotoBrowser' do

pod 'HanekeSwift', git: 'https://github.com/Haneke/HanekeSwift.git', branch: 'feature/swift-3', submodules: true
pod "youtube-ios-player-helper", "~> 0.1.4"

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end
