# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'RACMotionSignupDemo'
  app.deployment_target = '5.1'
  app.info_plist.update('UIMainStoryboardFile' => 'MainStoryboard_iPhone', 'UIMainStoryboardFile~ipad' => 'MainStoryboard_iPad')
  app.vendor_project 'vendor/ReactiveCocoa/ReactiveCocoaFramework', :xcode, target: 'ReactiveCocoa-iOS', headers_dir: 'ReactiveCocoa'
end
