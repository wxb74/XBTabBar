source 'https://cdn.cocoapods.org/'
platform :ios, '15.0'

project 'XBTabBarDemo.xcodeproj'

target 'XBTabBarDemo' do
  # 开发本仓库的组件；Masonry 由 XBTabBar.podspec 声明并自动安装。
  pod 'XBTabBar', :path => '.'

  target 'XBTabBarTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
