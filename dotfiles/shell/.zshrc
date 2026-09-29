# ==========================================
# PATH & ENVIRONMENT
# ==========================================
export PATH="$HOME/.local/bin:$HOME/.spicetify:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# ==========================================
# OH MY ZSH SETUP
# ==========================================
export ZSH="$HOME/.oh-my-zsh"

# Gunakan theme favoritmu (atau kosongkan jika pakai starship)
ZSH_THEME="robbyrussell"

# Disable dirty check di repo raksasa biar prompt tetap kencang
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Plugins esensial ngoding + navigasi
plugins=(
  git
  history
  sudo
  extract
  docker
  docker-compose
  npm
  yarn
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
  fzf-tab
)

source $ZSH/oh-my-zsh.sh

# ==========================================
# HISTORY & SHELL BEHAVIOR
# ==========================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt HIST_IGNORE_ALL_DUPS   # Hapus duplikasi command lama
setopt SHARE_HISTORY          # Sinkronisasi riwayat command antar-tab
setopt AUTO_CD                # Ketik nama folder langsung cd
setopt AUTO_PUSHD             # Ingat riwayat navigasi folder
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# ==========================================
# FZF-TAB CONFIG (TAB AUTOCOMPLETE MODERN)
# ==========================================
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group ',' '.'

# ==========================================
# ALIASES
# ==========================================

# --- Config & System ---
alias zshconfig="nvim ~/.zshrc"
alias reload="source ~/.zshrc"
alias cls="clear"
alias update="winget upgrade --all"

# --- Navigation & Listing ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ll="ls -lah"
alias la="ls -A"
alias l="ls -CF"

# Safety confirmation
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# --- Git Shortcuts ---
alias gs="git status"
alias ga="git add"
alias gaa="git add ."
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --decorate"


alias bismillah="python auto_dev.py"

# --- Docker ---
alias dc="docker compose"
alias dps="docker ps"
alias di="docker images"
alias ddown="docker compose down"
alias dup="docker compose up -d"

# --- JS / TS / Web Dev ---
alias nr="npm run"
alias nrd="npm run dev"
alias nrb="npm run build"
alias pd="pnpm dev"
alias pb="pnpm build"
alias yd="yarn dev"
alias yb="yarn build"

# --- Spicetify ---
alias spa="spicetify apply"
alias sba="spicetify backup apply"
alias su="spicetify update"

# --- yt-dlp & Media ---
alias ff="ffmpeg"
alias dl="yt-dlp --cookies-from-browser firefox"
alias fdownload="yt-dlp --cookies-from-browser firefox -F"
alias dlmp3='yt-dlp --cookies-from-browser firefox -x --audio-format mp3'
alias dl1080='yt-dlp --cookies-from-browser firefox -S ext:mp4,res:1080 -f bv+ba'
alias dl4k='yt-dlp --cookies-from-browser firefox -S ext:mp4,res:2160 -f bv+ba'

# ==========================================
# RUNTIMES & HOOKS (Optional - un-comment jika terpasang)
# ==========================================
# eval "$(zoxide init zsh)"
# eval "$(starship init zsh)"

# GEMINI API KEY
export GEMINI_API_KEY="<REDACTED>"
