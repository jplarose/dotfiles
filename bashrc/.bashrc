#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#######################################################
# Aliases
#######################################################

# Common Aliases
alias ls='ls -la --color=auto'
alias grep='grep --color=auto'
alias rg='rg -. -M 100 -i --no-messages --color=auto'
alias yt='yt-dlp -f "bv*+ba/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail'

# Custom Aliases
alias dev='cd /home/jlarose/Dev'

#######################################################
# Common Settings Tweaks
#######################################################
export EDITOR=nvim

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

PS1='[\u@\h \W]\$ '

# Path
export PATH="$HOME/.local/bin:$PATH"

#######################################################
# Custom Functions
#######################################################

#Automatically do an ls after each cd
 cd ()
 {
 	if [ -n "$1" ]; then
 		builtin cd "$@" && \ls --color=always
 	else
 		builtin cd ~ && \ls --color=always
 	fi
 }

eval "$(oh-my-posh init bash --config ~/.config/plague.omp.json)"

# Load machine-local aliases last so they override repo defaults
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
