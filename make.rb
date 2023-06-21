require 'bundler'
require 'fileutils'

FileUtils.rm_rf 'tmp'
FileUtils.mkdir_p 'tmp'

unless File.exists?('ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/bin/ruby')
  system *['git', 'clone', 'https://github.com/ahogappa0613/ruby.wasm.git']

  FileUtils.cd('ruby.wasm') do |dir|
    system *[
      'docker', 'run', '-it',
      '-v', '.:/home/me/build',
      '-w', '/home/me/build',
      '-e', '"RUBYWASM_UID=$(id -u)"',
      '-e', '"RUBYWASM_GID=$(id -g)"',
      'wasm-builder', 'rake', 'build:head-wasm32-unknown-wasi-full-debug'
    ]
  end
end

unless File.exists?('wasi-sdk.tar.gz')
  system *['curl', '-L',
    '-o', 'wasi-sdk.tar.gz',
    'https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-14/wasi-sdk-14.0-macos.tar.gz'
  ]
end

unless File.exists?('./wasi-sdk')
  FileUtils.mkdir_p 'wasi-sdk'
  system "tar -C ./wasi-sdk --strip-component 1 -xzf wasi-sdk.tar.gz"
end

pwd = FileUtils.pwd

FileUtils.cp(
   '/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/lib/libruby-static.a',
   '/Users/ahogappa/project/ruby-pack-wasm/ruby.a'
)

Bundler.load.specs.reject { |spec| spec.name == 'bundler' }.each do |spec|
  path = spec.full_gem_path

  FileUtils.cp_r(path, 'tmp')
  spec.extensions.each do |extension|
    system *[
      'ruby', File.join('tmp', spec.full_name, extension),
      # 'CC=/Users/ahogappa/project/ruby-pack-wasm/wasi-sdk/bin/clang',
      # "--with-opt-dir=#{File.join(pwd, '/ruby.wasm/build/wasm32-unknown-wasi/head-wasm32-unknown-wasi-full-debug/install/usr/local')}",
    ]

    FileUtils.cd(File.dirname(File.join('tmp', spec.full_name, extension))) do |dir|
      system 'make clean'
      system *[
        'make',
        'V=1',
        # "DLLIB=byebug.wasm"
        "CC=#{File.join(pwd, '/wasi-sdk/bin/clang')} --sysroot=#{File.join(pwd, '/wasi-sdk/share/wasi-sysroot')} -I/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/include/ruby-3.3.0+0 -I/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/include/ruby-3.3.0+0/wasm32-wasi -L/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/lib",
        "LD=#{File.join(pwd, '/wasi-sdk/bin/clang')}",
        "AR=#{File.join(pwd, '/wasi-sdk/bin/llvm-ar')}",
        "RANLIB=#{File.join(pwd, '/wasi-sdk/bin/llvm-ranlib')}",
        "RUBY_SO_NAME=ruby-static",
      ]

      objs = File.readlines('Makefile').grep(/^OBJS = (.*\.o)+/)
      objs[0].match(/^OBJS = (.*\.o)+/)

      args = $1.split(' ')

      # system *[
      #   "#{File.join(pwd, '/wasi-sdk/bin/wasm-ld')}",
      #   "-o", '/Users/ahogappa/project/ruby-pack-wasm/ruby.a',
      #   '/Users/ahogappa/project/ruby-pack-wasm/ruby.a',
      #   *args,
      # ]
    end
  end
end

=begin
/Users/ahogappa/project/ruby-pack-wasm/wasi-sdk/bin/clang \
--sysroot=/Users/ahogappa/project/ruby-pack-wasm/wasi-sdk/share/wasi-sysroot \
-nostartfiles \
-Wl,--no-entry \
-I/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/include/ruby-3.3.0+0 \
-I/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/include/ruby-3.3.0+0/wasm32-wasi \
-L/Users/ahogappa/project/ruby-pack-wasm/ruby.wasm/rubies/head-wasm32-unknown-wasi-full-debug/usr/local/lib \
-lruby-static \
-o byebug.wasm \
*.c \
end

