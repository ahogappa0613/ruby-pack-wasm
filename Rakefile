exit unless File.exist?("Gemfile.lock")

unless Dir.exist?("ruby.wasm")
  system "git clone -b featur/ruby_wasm_pack https://github.com/ahogappa0613/ruby.wasm.git"
end

require "./ruby.wasm/lib/ruby_wasm/rake_task"
require "./lib/wasm_cp_ext_task"

WASM_ROOT = File.join(File.dirname(__FILE__), "ruby.wasm")

options = {
  build_dir: File.join(WASM_ROOT, "build"),
  rubies_dir: File.join(WASM_ROOT, "rubies"),
  src: {
    type: "github",
    repo: "ruby/ruby",
    rev: "v3_2_0",
    name: "3_2"
  },
  target: "wasm32-unknown-wasi",
  default_exts:
    "bigdecimal,cgi/escape,continuation,coverage,date,dbm,digest/bubblebabble,digest,digest/md5,digest/rmd160,digest/sha1,digest/sha2,etc,fcntl,fiber,gdbm,json,json/generator,json/parser,nkf,objspace,pathname,psych,racc/cparse,rbconfig/sizeof,ripper,stringio,strscan,monitor,zlib,openssl"
}

namespace :build do
  desc "Clean build directories"
  task :clean do
    rm_rf "./ruby.wasm/build"
    rm_rf "./ruby.wasm/rubies"
  end

  task =
    RubyWasm::BuildTask.new("wasm-pack-ruby", **options) do |t|
      # debug build
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
      cp_task = RubyWasm::CpExtTask.new(WASM_ROOT, toolchain)

      if cp_task.cp_exts.used_rust_exts?
        t.crossruby.with_wasi_vfs nil
      end

      t.crossruby.user_exts =
        # %w[js witapi]
        %w[]
          .map do |ext|
            srcdir = File.join(WASM_ROOT, "ext", ext)
            RubyWasm::CrossRubyExtProduct.new(srcdir, toolchain)
          end
          .concat(cp_task.exts)
    end

  task
end
