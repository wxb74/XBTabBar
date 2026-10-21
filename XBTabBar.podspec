Pod::Spec.new do |s|
  s.name = 'XBTabBar'
  s.version = '0.1.0'
  s.summary = 'A configurable multi-tab container and standalone tab bar for UIKit.'
  s.description = <<-DESC
    An Objective-C tab container with independent navigation stacks, page and action items,
    raised buttons, badges, six image/title layouts, per-item appearance and selection animations.
  DESC
  s.homepage = 'https://github.com/wxb74/XBTabBar'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'wxb74' => '20829102+wxb74@users.noreply.github.com' }
  s.source = { :git => 'https://github.com/wxb74/XBTabBar.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.source_files = 'XBTabBar/*.{h,m}'
  s.public_header_files = 'XBTabBar/*.h'
  s.frameworks = 'UIKit', 'QuartzCore'
  s.module_name = 'XBTabBar'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.dependency 'Masonry', '~> 1.1'
end
