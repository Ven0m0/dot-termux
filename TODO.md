- https://github.com/ahmed-alnassif/AndroSH/discussions/6#discussioncomment-15720947
- https://github.com/ahmed-alnassif/AndroSH/blob/main/Assets/docs/AndroSH_Help.md

```bash
pkg i -y uv
uv pip install requests beautifulsoup4 pandas numpy matplotlib

pkg i -y termux-x11-nightly socat
git clone --depth 1 https://github.com/ahmed-alnassif/AndroSH.git && cd AndroSH
pip install -r requirememts # uc fails here
```

- allow installing this whole repo with one bash piped script.

_ add: https://github.com/jecis-repos/termux-shizuku-tools

- https://github.com/sabamdarif/chroot-distro
- https://github.com/vkdatta/bashbasicsbyvk


```~/.bashrc```

```bash
npm install -g @anthropic-ai/claude-code
npm install -g @mmmbuto/gemini-cli-termux@latest @mmmbuto/nexuscli
alias claude='node /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js'
```

- https://github.com/DioNanos/nexuscli
- https://github.com/DioNanos/qwen-code-termux
- https://github.com/DioNanos/gemini-cli-termux
- https://github.com/DioNanos/codex-termux
