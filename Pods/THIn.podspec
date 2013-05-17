Pod::Spec.new do |s|
  s.name     = 'THIn'
  s.version  = '0.0.0'
  s.homepage = 'https://github.com/th-in-gs/THIn'
  s.author   = { 'James Montgomerie' => 'jamie@th.ingsmadeoutofotherthin.gs' }
  s.source   = { :git => 'https://github.com/th-in-gs/THIn.git' }
  s.platform = :ios
  s.source_files = 'THIn/*.{h|m}'
  s.requires_arc = true
end
