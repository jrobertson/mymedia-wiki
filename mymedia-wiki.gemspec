Gem::Specification.new do |s|
  s.name = 'mymedia-wiki'
  s.version = '0.5.1'
  s.summary = 'Transforms a kind of Markdown document using Kramdown and XSLT.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia-wiki.rb']
  s.add_runtime_dependency('mymedia-pages', '~> 0.6', '>=0.6.0')
  s.signing_key = '../privatekeys/mymedia-wiki.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mymedia-wiki'
end
