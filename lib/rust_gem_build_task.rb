require "toml-rb"

module RubyWasm
  class RustGemProduct < BuildProduct
    RUST_LIB_NAME = "rust_lib"
    WASI_VFS_NAME = "wasi_vfs"

    def initialize(dir, toolchain, exts)
      @lib_dir = dir
      @toolchain = toolchain
      @exts = exts
    end

    def name
      @exts.map { |ext| ext[:name] }.join(" ")
    end

    def product_build_dir(crossruby)
      File.join(crossruby.ext_build_dir, RUST_LIB_NAME)
    end

    def linklist(crossruby)
      File.join(product_build_dir(crossruby), "link.filelist")
    end

    def wasi_vfs_path
      ENV["GIT_WASI_VFS_PATH"
    end

    def cargo_new_lib(dir)
      system "cargo new #{RUST_LIB_NAME} --lib", chdir: dir
    end

    def cargo_add(ext)
      system "cargo add #{ext[:name]} --path #{ext[:dir]}"
    end

    def lib_rs
      @exts.map { |ext| "pub use #{ext[:name]};" }.join("\n")
    end

    def replace_src(path)
      File.write(path, "pub use #{WASI_VFS_NAME};\n" + lib_rs)
    end

    def crate_types
      %w[lib cdylib]
    end

    def replace_cargo_toml(dir)
      path = File.join(dir, "Cargo.toml")
      cargo = TomlRB.load_file(path)
      cargo["lib"] = { "crate-type" => crate_types }
      File.write(path, TomlRB.dump(cargo))
    end

    def create_linklist(crossruby, dir)
      File.write(linklist(crossruby), Dir.glob("#{dir}/*.a").join("\n"))
    end

    def build(crossruby)
      unless Dir.exist?(product_build_dir(crossruby))
        cargo_new_lib(crossruby.ext_build_dir)
      end

      FileUtils.chdir(product_build_dir(crossruby)) do |dir|
        system "cargo add wasi-vfs --path #{wasi_vfs_path} --rename #{WASI_VFS_NAME}"
        @exts.each do |ext|
          cargo_add(ext)
          replace_cargo_toml(ext[:dir])
        end

        replace_src("./src/lib.rs")

        target = "wasm32-wasi"

        envs = [
          "RBCONFIG_CPPFLAGS='-D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_GETPID -D_WASI_EMULATED_PROCESS_CLOCKS -I#{File.join(@toolchain.wasi_sysroot_path, "include")}'",
          "RBCONFIG_rubyarchhdrdir='#{crossruby.ruby_config_path}'",
          "RBCONFIG_rubyhdrdir='#{crossruby.ruby_header_path}'"
        ]
        args = ["--target=#{target}", "--release", "--crate-type=staticlib"]
        codegen_args = []

        system "#{envs.join(" ")} cargo rustc #{args.join(" ")} -- #{codegen_args.join(" ")}"

        create_linklist(
          crossruby,
          File.join(dir, "target", "#{target}", "release")
        )
      end
    end

    def do_install_rb(crossruby)
      dir =
        Dir.glob(
          File.join(
            crossruby.dest_dir,
            "usr",
            "local",
            "lib",
            "ruby",
            "site_ruby",
            "*"
          )
        ).first
      @exts.each do |ext|
        system("cp -r #{File.join(ext[:dir], "lib", "*")} #{dir}")
      end
    end
  end
end
