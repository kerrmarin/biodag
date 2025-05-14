Pod::Spec.new do |spec|
    spec.name          = 'Biodag'
    spec.version       = '0.4.1'
    spec.license       = { :type => 'MIT', :file => 'LICENSE' }
    spec.homepage      = 'https://github.com/kerrmarin/biodag'
    spec.authors       = { 'Kerr Marin Miller' => 'kerr@kerrmarin.com' }
    spec.summary       = 'A Swift micro-library that provides lightweight dependency injection.'
    spec.source        = { :git => 'https://github.com/kerrmarin/biodag.git', :tag => spec.version.to_s }
    spec.swift_version = '5.10'
  
    spec.ios.deployment_target  = '16.0'
  
    spec.source_files       = 'Sources/Biodag/*.swift'
end
