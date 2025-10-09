```bash
bash -c "$(curl -sLo- https://superfile.dev/install.sh)"
```

Zush
```sh
curl -fsSL https://raw.githubusercontent.com/shyndman/zush/main/install.sh | zsh
```

Zinit
```sh
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
```





```sh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"
```
```sh
git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
```
```sh
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```



Scripts
```bash
https://github.com/kitikonti/script-image-optimizer/blob/main/optimize-images.sh

```
```
cargo install --git https://github.com/Blobfolio/flaca.git --bin flaca
```

- https://github.com/AvinashReddy3108/LITMux


Rust stuff
```sh
pkg in -y sccache mold
export RUSTC_LINKER=clang
export OPT_LEVEL=3
export CARGO_CACHE_RUSTC_INFO=1
export RUSTFLAGS="-Copt-level=3 -Ctarget-cpu=native -Ccodegen-units=1 -Cstrip=symbols -Clink-arg=-fuse-ld=mold"
export RUSTC_WRAPPER=sccache
export CARGO_HTTP_MULTIPLEXING=true CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_HTTP_SSL_VERSION="tlsv1.3"
cargo install rimage --features="build-binary"cargo install \
    --git https://github.com/Blobfolio/flaca.git \
    --bin flaca

```

apk's:

- https://github.com/REAndroid/APKEditor


