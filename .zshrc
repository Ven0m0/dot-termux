


ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
[[ -z "${plugins[*]}" ]] && plugins=(git fzf extract aliases)
source $ZSH/oh-my-zsh.sh
export HISTIGNORE="&:[bf]g:c:clear:history:exit:q:pwd:* --help"
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
