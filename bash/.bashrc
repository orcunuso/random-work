# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Define colors
DULL=0
BRIGHT=1

FG_BLACK=30
FG_RED=31
FG_GREEN=32
FG_YELLOW=33
FG_BLUE=34
FG_VIOLET=35
FG_CYAN=36
FG_WHITE=37

FG_NULL=00

BG_BLACK=40
BG_RED=41
BG_GREEN=42
BG_YELLOW=43
BG_BLUE=44
BG_VIOLET=45
BG_CYAN=46
BG_WHITE=47

BG_NULL=00

##
# ANSI Escape Commands
##
ESC="\033"
NORMAL="\[$ESC[m\]"
RESET="\[$ESC[${DULL};${FG_WHITE};${BG_NULL}m\]"

##
# Shortcuts for Colored Text ( Bright and FG Only )
##

# DULL TEXT

BLACK="\[$ESC[${DULL};${FG_BLACK}m\]"
RED="\[$ESC[${DULL};${FG_RED}m\]"
GREEN="\[$ESC[${DULL};${FG_GREEN}m\]"
YELLOW="\[$ESC[${DULL};${FG_YELLOW}m\]"
BLUE="\[$ESC[${DULL};${FG_BLUE}m\]"
VIOLET="\[$ESC[${DULL};${FG_VIOLET}m\]"
CYAN="\[$ESC[${DULL};${FG_CYAN}m\]"
WHITE="\[$ESC[${DULL};${FG_WHITE}m\]"

# BRIGHT TEXT
BRIGHT_BLACK="\[$ESC[${BRIGHT};${FG_BLACK}m\]"
BRIGHT_RED="\[$ESC[${BRIGHT};${FG_RED}m\]"
BRIGHT_GREEN="\[$ESC[${BRIGHT};${FG_GREEN}m\]"
BRIGHT_YELLOW="\[$ESC[${BRIGHT};${FG_YELLOW}m\]"
BRIGHT_BLUE="\[$ESC[${BRIGHT};${FG_BLUE}m\]"
BRIGHT_VIOLET="\[$ESC[${BRIGHT};${FG_VIOLET}m\]"
BRIGHT_CYAN="\[$ESC[${BRIGHT};${FG_CYAN}m\]"
BRIGHT_WHITE="\[$ESC[${BRIGHT};${FG_WHITE}m\]"

# REV TEXT as an example
REV_CYAN="\[$ESC[${DULL};${BG_WHITE};${BG_CYAN}m\]"
REV_RED="\[$ESC[${DULL};${FG_YELLOW}; ${BG_RED}m\]"

PS1="$GREEN[$BRIGHT_CYAN OrcunusO $GREEN\w $GREEN]$BRIGHT_YELLOW#$NORMAL$RESET "
#PS1="$BLUE[$RED\u$BLUE@$BRIGHT_CYAN\h$BLUE:$GREEN\w$BLUE]$BRIGHT_YELLOW#$NORMAL$RESET "
#PS1="${BRIGHT_CYAN}[${CYAN}\u$@\h${WHITE}:\w${BRIGHT_CYAN}]${NORMAL}\$ ${RESET}"
 
set -o notify
set -o noclobber
#set -o ignoreeof
 
shopt -s cdspell
shopt -s cdable_vars
shopt -s checkhash
shopt -s checkwinsize
shopt -s sourcepath
shopt -s histappend 
shopt -s histreedit
shopt -s extglob        # useful for programmable completion
#shopt -s mailwarn
#shopt -s no_empty_cmd_completion
 
unset MAILCHECK

# Set various aspects of the bash history
export HISTFILE=~/.bash_history
export HISTSIZE=5000 # Num. of commands in history stack in memory
export HISTFILESIZE=5000 # Num. of commands in history FILE
#export HISTIGNORE='&:[ ]*' # bash >= 3, omit dups & lines starting with space
export HISTTIMEFORMAT='%Y-%m-%d %H:%M:%S ' # bash >= 3, time-stamp hist file
shopt -s histappend # Append rather than overwrite history on exit

export PATH=$PATH:/usr/lbin/:$HOME/bin:/opt/OV/bin:/opt/OV/bin/OpC
export TILLER_NAMESPACE='kube-tiller'

# User specific aliases and functions

#alias rm='rm -i'
#alias cp='cp -i'
#alias mv='mv -i'
alias vi=vim 
alias h='history'
alias j='jobs -l'
alias ..='cd ..'
alias path='echo -e ${PATH//:/\\n}'
alias dockerauth='cat $HOME/.docker/config.json'
alias dockerps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Command}}" --no-trunc'
alias oc='oc11'
alias ocsource='source <(oc completion bash)'
alias ocnodelistpods='oc adm manage-node --list-pods'
alias ocnodemaintenanceon='oc adm manage-node --schedulable=false'
alias ocnodemaintenanceoff='oc adm manage-node --schedulable=true'
alias ocnodedrain='oc adm drain --delete-local-data --force --ignore-daemonsets --grace-period=120'

alias ksource='source <(kubectl completion bash)'
alias kpod='kubectl get pods -o wide --all-namespaces'
alias ksvc='kubectl get services -o wide --all-namespaces'
alias kdep='kubectl get deployments -o wide --all-namespaces'
alias kds='kubectl get daemonsets -o wide --all-namespaces'
alias king='kubectl get ingress -o wide --all-namespaces'
alias knode='kubectl get nodes -o wide'
alias kcreate='kubectl create -f'
alias kapply='kubectl apply -f'
alias kget='kubectl get -o wide'

