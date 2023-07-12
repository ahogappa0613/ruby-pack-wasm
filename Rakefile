require 'bundler'

exit unless File.exist?('Gemfile.lock')

exts = []

unless Dir.exist?('ruby.wasm')
  system 'git clone -b fix/build_error_on_my_env https://github.com/ahogappa0613/ruby.wasm.git'
end

# Gemfile.lockから情報をとるぞ
Bundler.load.specs.reject { |spec| spec.name == 'bundler' }.each do |spec|
  next if spec.extensions.empty?

  FileUtils.rm_rf("ruby.wasm/ext/#{spec.name}") if Dir.exist?("ruby.wasm/ext/#{spec.name}")

  src_dir = File.join(spec.full_gem_path, 'ext')
  FileUtils.cp_r(src_dir, 'ruby.wasm')
  system "ruby #{FileUtils.pwd}/depend.erb #{spec.name} >> #{File.join(FileUtils.pwd, 'ruby.wasm', File.dirname(spec.extensions[0]), 'depend')}"

  exts << { name: spec.name, dir: File.dirname(spec.extensions[0]) }
end

LIB_ROOT = File.join(File.dirname(__FILE__), 'ruby.wasm')
# wasmでbuildするぞ
require './ruby.wasm/lib/ruby_wasm/rake_task'

options = {
  build_dir: File.join(LIB_ROOT, 'build'),
  rubies_dir: File.join(LIB_ROOT, 'rubies'),
  src: {
    type: 'github',
    repo: 'ruby/ruby',
    rev: 'v3_2_0',
    name: '3_2'
  },
  target: 'wasm32-unknown-wasi',
  default_exts: 'bigdecimal,cgi/escape,continuation,coverage,date,dbm,digest/bubblebabble,digest,digest/md5,digest/rmd160,digest/sha1,digest/sha2,etc,fcntl,fiber,gdbm,json,json/generator,json/parser,nkf,objspace,pathname,psych,racc/cparse,rbconfig/sizeof,ripper,stringio,strscan,monitor,zlib,openssl'
}

# TOOLCHAINS = {}

namespace :build do
  desc 'Clean build directories'
  task :clean do
    rm_rf './ruby.wasm/build'
    rm_rf './ruby.wasm/rubies'
  end

  task = RubyWasm::BuildTask.new('experimental-ruby', **options) do |t|
    t.crossruby.debugflags = %w[-g]
    t.crossruby.wasmoptflags = %w[-O3 -g]
    t.crossruby.ldflags = %w[
      -Xlinker
      --stack-first
      -Xlinker
      -z
      -Xlinker
      stack-size=16777216
    ]

    toolchain = t.toolchain
    t.crossruby.user_exts =
      exts.map do |ext|
        srcdir = File.join(LIB_ROOT, ext[:dir])
        RubyWasm::CrossRubyExtProduct.new(srcdir, toolchain, name: ext[:name])
      end
    # unless TOOLCHAINS.key? toolchain.name
    #   TOOLCHAINS[toolchain.name] = toolchain
    # end
  end

  task
end
