require "bundler"
require "set"
require_relative "./rust_gem_build_task.rb"

module RubyWasm
  class CpExtTask
    attr_reader :clang_exts, :rust_exts

    def initialize(
      dest_dir,
      toolchain,
      default_clnag_exts = [],
      default_rust_exts = []
    )
      @clang_exts = Set.new(default_clnag_exts)
      @rust_exts = Set.new(default_rust_exts)
      @dest_dir = dest_dir
      @toolchain = toolchain
    end

    def used_rust_exts?
      !@rust_exts.empty?
    end

    # TODO: 今はnaive拡張のみをコピーしているが
    #       今後は純粋なruby gemもコピーする必要がある
    def cp_exts
      Bundler
        .load
        .specs
        .reject { |spec| spec.name == "bundler" }
        .each do |spec|
          # TODO: dependencyで必要なgemでnative拡張があるならそれも含める必要がある
          #       ので、本来は依存関係も全て見る必要あり
          unless spec.extensions.empty?
            ext_gem_dir = File.join(@dest_dir, "ext", spec.name)
            ext = { name: spec.name, dir: ext_gem_dir }

            # 関連ファイルのコピー
            src_dir = File.join(spec.full_gem_path, "ext") # MEMO: bundle gem gem_name --ext で生成されるディレクトリに依存している
            FileUtils.cp_r(src_dir, @dest_dir)
            lib_dir = File.join(spec.full_gem_path, "lib")
            FileUtils.cp_r(lib_dir, ext_gem_dir)

            # bundleファイルではなく、リンクしたものを使うために、
            # 明示的に.soをrequireするだけのファイルを作成し、bundleファイルは削除する
            # TODO: bundleファイルが複数存在するような拡張の時の対応
            ext_path = Dir.glob(File.join(ext_gem_dir, "**/*.{bundle,so}")).first
            FileUtils.rm ext_path
            file_name = File.basename(ext_path, File.extname(ext_path))
            create_require_rb(
              File.join(File.dirname(ext_path), "#{file_name}.rb"),
              file_name
            )

            if spec.extensions.any? /Cargo\.toml/ # Rustの拡張
              @rust_exts << ext
            else # C言語の拡張
              # deoendファイルの生成
              FileUtils.rm File.join(ext_gem_dir, "depend")
              system "ruby #{File.dirname(__FILE__)}/depend.erb #{spec.name} >> #{File.join(@dest_dir, File.dirname(spec.extensions[0]), "depend")}"

              @clang_exts << ext
            end
          end
        end

      self
    end

    def create_require_rb(path, name)
      File.write(path, "require '#{name}.so'")
    end

    def exts
      exts = []

      exts +=
        unless @clang_exts.empty?
          @clang_exts.map do |ext|
            RubyWasm::CrossRubyExtProduct.new(
              ext[:dir],
              @toolchain,
              name: ext[:name]
            )
          end
        end

      exts +=
        unless @rust_exts.empty?
          [RubyWasm::RustGemProduct.new(@dest_dir, @toolchain, @rust_exts)]
        end

      exts
    end
  end
end
