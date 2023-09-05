以下の手順で、wasm-pack-ruby をビルドします。

```sh
$ bundle install
$ rake build:wasm-pack-ruby
```

できあがった、`ruby.wasm/rubies/wasm-pack-ruby/usr/local/bin/ruby`を使ってマウントして、実行すると通常の実行と同じ結果を得ることができます。

```sh
$ wasi-vfs pack ruby.wasm/rubies/wasm-pack-ruby/usr/local/bin/ruby --mapdir /src::./src --mapdir /usr::./ruby.wasm/rubies/wasm-pack-ruby/usr -o ruby_pack.wasm
$ wasmtime ruby_pack.wasm -- /src/hello.rb
```
