platform :ios, '10.0'
use_frameworks!

abstract_target 'abstract_target' do
  inhibit_all_warnings!

  pod 'Alamofire'
  pod 'PromiseKit'
  pod 'CancelForPromiseKit'
  pod 'CancelForPromiseKit/Alamofire'
  pod 'AlamofireCoreData'
  pod 'baseapp-ios-core-v1',
    :git => 'git@bitbucket.org:silverlogic/baseapp-ios-core-v1.git',
    :branch => '0.1.25'

  target 'Raccoon'

  target 'RaccoonTests' do
      pod 'OHHTTPStubs', '~> 5.2'
      pod 'OHHTTPStubs/Swift', '~> 5.2'
  end
end





post_install do |installer_representation|
	installer_representation.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			config.build_settings['GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS'] = 'NO'
			config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
		end
	end
end
