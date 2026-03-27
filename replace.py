import sys

with open('setup-shizu.sh', 'r') as f:
    content = f.read()

old_block = """# Lucky Patcher and System tools
find "$PWD"/lucky-patcher "$PWD"/system -name "*.sh" -type f -print0 2>/dev/null | xargs -0 -r ln -sf -t ~/bin/

# AI tools
find "$PWD"/ai-tools -type f -print0 2>/dev/null | xargs -0 -r ln -sf -t ~/bin/"""

new_block = """# Lucky Patcher and System tools
find "$PWD"/lucky-patcher "$PWD"/system -maxdepth 1 -name "*.sh" -type f -print0 2>/dev/null | xargs -0 -r ln -sf -t ~/bin/

# AI tools
find "$PWD"/ai-tools -maxdepth 1 ! -name ".*" -type f -print0 2>/dev/null | xargs -0 -r ln -sf -t ~/bin/"""

if old_block in content:
    new_content = content.replace(old_block, new_block)
    with open('setup-shizu.sh', 'w') as f:
        f.write(new_content)
    print("Replaced successfully")
else:
    print("Block not found!")
    sys.exit(1)
