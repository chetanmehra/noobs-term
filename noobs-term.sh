main() {

set -e

# colors
  if which tput >/dev/null 2>&1; then
      ncolors=$(tput colors)
  fi
  if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    BLUE="$(tput setaf 4)"
    PURP="$(tput setaf 5)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
  else
    BLUE=""
    PURP=""
    BOLD=""
    NORMAL=""
fi

# dotfiles
dotfiles=" \
    .tmux.conf \
    .zshrc \
    .tmux \
    .zsh \
    .oh-my-zsh \
    "

# package dependencies
dependencies=" \
    git \
    curl \
    wget \
    zsh \
    tmux \
    neovim \
    "

dotfiles_dir="$HOME/.dotfiles" # dotfiles directory
dotfiles_repo="https://github.com/aaronkjones/noobs-term-dotfiles.git" # dotfiles repo
nvim_config="$HOME/.config/nvim/init.vim" # neovim config location
platform="unknown" # default to unknown platform

# make git be quiet
quiet_git() {
    stdout=$(mktemp)
    stderr=$(mktemp)

    if ! git "$@" </dev/null >"$stdout" 2>"$stderr"; then
        cat "$stderr" >&2
        rm -f "$stdout" "$stderr"
        exit 1
    fi

    rm -f "$stdout" "$stderr"
}
printf "${PURP}"
# backup dotfiles
backup_dotfiles() {
    echo "Backing up old dotfiles..."
    for d in $dotfiles; do 
    cp -rf "$HOME/$d" "$HOME/$d.backup" 2>/dev/null || :
    done
    cp -rf "$dotfiles_dir" "$dotfiles_dir.backup" 2>/dev/null || :
    cp -f "$nvim_config" "$HOME/.config/nvim/init.vim.backup" 2>/dev/null || :
    echo "Done"
}

# remove dotfiles
remove_old_dotfiles() {
    echo "Removing old dotfiles..."
    for d in $dotfiles; do 
    rm -rf "${HOME:?}"/"$d"
    done
    rm -rf "$dotfiles_dir"
    rm -f "$nvim_config"
    echo "Done"
}

# install dotfiles
install_dotfiles() {
echo "Installing dotfiles into $dotfiles_dir..."
quiet_git clone "$dotfiles_repo" "$dotfiles_dir"
echo "Symbollically linking dotfiles to home directory (e.g. ln -s $dotfiles_dir/.zshrc $HOME/.zshrc)"
find "$dotfiles_dir" -type f -name ".*" -exec ln -sf {} "$HOME" \; > /dev/null 2>&1
if [ ! -d "$HOME/.config/nvim" ]; then
    mkdir -p "$HOME/.config/nvim"
fi
ln -s "$dotfiles_dir/init.vim" "$nvim_config"
    echo "Done"
}

# backup and remove dotfiles
if [ -d "$dotfiles_dir" ]; then
    echo "Old dotfiles exist"
    echo
    backup_dotfiles
    echo
    remove_old_dotfiles
    echo
fi
# find current platform and distribution
if [ "$(uname)" = 'Linux' ]; then
platform='Linux'
    if type lsb_release >/dev/null 2>&1; then
    distro="$(lsb_release -si)"
    elif [ -f "/etc/arch-release" ]; then
      distro='Arch'
    fi
elif [ "$(uname)" = 'Darwin' ]; then
platform='Mac'
fi
echo "Current platform: $platform"
if [ "$platform" = 'Linux' ]; then
    echo "Current distribution: $distro"
fi
echo
# add neovim repo
if [ "$distro" = 'Ubuntu' ]; then
    if ! command -v nvim; then
        echo "Adding Neovim Repository..."
        /usr/bin/sudo apt-add-repository ppa:neovim-ppa/stable -y 1> /dev/null
        echo "Done"
    fi
fi
echo
# install dependencies
# linux
echo "Installing dependencies..."
if [ "$platform" = 'Linux' ]; then
    if [ "$distro" = 'Ubuntu' ]; then
        /usr/bin/sudo apt-get -qq update
        for p in $dependencies; do
            /usr/bin/sudo apt-get -qq install -y "$p"
        done
    elif [ "$distro" = 'Arch' ]; then
        for p in $dependencies; do
            /usr/bin/sudo pacman -q -S --noconfirm "$p" 1>/dev/null
        done
fi
# mac
elif [ $platform = 'Mac' ]; then
    if ! type "$(which brew)"; then
        echo "Brew not installed. Installing..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    else
        echo "Brew already installed. Proceeding..."
        echo
    fi
   echo "Installing dependencies with Brew"
   echo
   for d in $dependencies; do
    brew info "$d" | grep --quiet 'Not installed' && brew install "$d"
    done
fi
echo "Done"
echo
# oh my zsh
echo "Installing Oh My Zsh..."
printf "${NORMAL}"
# Work around to non-standard shell error when chsh in oh-my-zsh script
if [ $platform = 'Mac' ]; then
  sudo dscl . -create /Users/$USER UserShell /usr/local/bin/zsh
fi
wget -q -O - https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | zsh
rm -f "$HOME/.zshrc" # remove oh-my-zsh supplied .zshrc
printf "${PURP}"
echo "Done"
echo
# install dotfiles
install_dotfiles
echo "Done"
echo
#  zsh plugins
echo "Installing Zsh plugins..." 
quiet_git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions/"
quiet_git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
quiet_git clone https://github.com/zsh-users/zsh-history-substring-search "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search"
quiet_git clone https://github.com/zsh-users/zsh-completions "$HOME/.oh-my-zsh/custom/plugins/zsh-completions"
echo "Done"
echo
# tmux package manager
echo "Installing Tmux package manager into $HOME/.tmux..."
quiet_git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
echo "Done"
echo
# vim-plug plugin manager
echo "Installing Vim-plug plugin manager into $HOME/.local/share/nvim/site/autoload/plug.vim..."
curl -sfLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
echo "Done"
echo
# activate nvim plugins
echo "Activating Neovim plugins..."
mkdir -p "$HOME/.config/nvim"
nvim +PlugInstall +qa || echo "Something went wrong installing Neovim plugins. Check init.vim for errors and try again."
echo "Done"
echo
# install imp theme for zsh
echo "Installing Imp theme for Zsh..."
curl -so "$HOME/.oh-my-zsh/themes/imp.zsh-theme" https://raw.githubusercontent.com/aaronkjones/Imp/master/imp.zsh-theme
echo "Done"
echo
# install nord theme for gnome terminal
    if [ "$platform" = 'Linux' ]; then
        # check if running desktop or headless
        if xhost > /dev/null 2>&1; then
        echo "Installing Nord theme for Gnome Terminal..."
        curl -sO https://raw.githubusercontent.com/arcticicestudio/nord-gnome-terminal/develop/src/nord.sh && chmod +x nord.sh && ./nord.sh
        rm -f nord.sh
        fi
    elif [ "$platform" = 'Mac' ]; then
        echo "Downloading Nord theme for iTerm"
        temp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
        wget -q -O "$temp_dir/Nord.itermcolors" https://raw.githubusercontent.com/arcticicestudio/nord-iterm2/master/src/xml/Nord.itermcolors
    fi
printf "${PURP}"
echo "Done"
echo
echo "Installing Powerline fonts..."
printf "${NORMAL}"
quiet_git clone https://github.com/powerline/fonts.git --depth=1 && \
    cd fonts && \
    ./install.sh && \
    cd .. && \
    rm -rf fonts
printf "${PURP}"
echo "Done"
echo
if [ "$platform" = 'Mac' ]; then
echo 'Installing Nord theme for iTerm...'
    open "$temp_dir/Nord.itermcolors"
fi
echo
printf "${BLUE}"
echo '
****************************************************************************************************'
echo '    _            __        ____      __  _                                           __     __     '
echo '   (_)___  _____/ /_____ _/ / /___ _/ /_(_)___  ____     _________  ____ ___  ____  / /__  / /____ '
echo '  / / __ \/ ___/ __/ __ `/ / / __ `/ __/ / __ \/ __ \   / ___/ __ \/ __ `__ \/ __ \/ / _ \/ __/ _ \'
echo ' / / / / (__  ) /_/ /_/ / / / /_/ / /_/ / /_/ / / / /  / /__/ /_/ / / / / / / /_/ / /  __/ /_/  __/'
echo '/_/_/ /_/____/\__/\__,_/_/_/\__,_/\__/_/\____/_/ /_/   \___/\____/_/ /_/ /_/ .___/_/\___/\__/\___/ '
echo '                                                                          /_/                      '
echo '***************************************************************************************************'
echo ''
echo "      * Note: You will have to log out and back in for Zsh to be set as the default shell."
echo "              If you don't want to log out now, enter 'zsh'"
echo ''
echo ''
echo '      * Press Ctrl + a, then I to load Tmux plugins'
echo ''
if [ "$platform" = 'Linux' ]; then
echo '      * In Gnome Terminal preferences, set Nord as your default profile'
elif [ "$platform" = 'Mac' ]; then
echo '      * In iTerm, set your color profile to Nord'
fi
echo ''
echo '      * Set an appropriate font (e.g. Inconsolata for Powerline)'
echo ''
echo ''

}
main
