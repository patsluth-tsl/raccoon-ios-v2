#
# Be sure to run `pod lib lint Raccoon.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|

  s.name                    = 'Raccoon'
  s.version                 = '2.1.7'
  s.summary                 = 'Puts together Alamofire, CoreData and PromiseKit'
  s.description             = 'A nice set of protocols and tools that puts together Alamofire, PromiseKit and CoreData.'
  s.homepage                = 'https://bitbucket.org/silverlogic/raccoon-ios-v2/'
  s.license                 = 'MIT'
  s.author                  = 'Manuel García-Estañ'
  s.social_media_url        = 'http://twitter.com/ManueGE'
  s.source                  = { :git => 'git@bitbucket.org:silverlogic/raccoon-ios-v2.git', :tag => s.version.to_s }

  s.swift_version = '5.0'
  s.requires_arc = true
  s.static_framework = true

  s.ios.deployment_target   = '10.0'

  s.ios.dependency          'Alamofire'
  s.ios.dependency          'PromiseKit'
  s.ios.dependency          'CancelForPromiseKit'
  s.ios.dependency          'CancelForPromiseKit/Alamofire'
  s.ios.dependency          'AlamofireCoreData'
  s.ios.dependency          'baseapp-ios-core-v1', '~> 0.2.5'

  s.ios.source_files =      'Raccoon/source/**/*.{swift}'

  s.ios.framework =         'CoreData'

end
