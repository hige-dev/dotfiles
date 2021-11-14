yum groupinstall "Development Tools"
sudo yum -y install curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc ncurses-devel libevent-devel
sudo yum update -y

# git
sudo tar -xzvf git-2.33.1.tar.gz
sudo curl -LO https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.33.1.tar.gz
cd /usr/lcoal/src/
cd git-2.33.1/
sudo make prefix=/usr/local all
sudo make prefix=/usr/local install

# vim
cd /usr/local/src/
git clone https://github.com/vim/vim.git
cd /usr/local/src/vim
sudo make
sudo make install

alias vi='vim'

## dein
mkdir -p ~/.cache/dein; cd $_
curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
sh ./installer.sh ~/.cache/dein


## vimplug
# https://github.com/junegunn/vim-plug

# tmux
cd cd /usr/local/src/
curl -LO https://github.com/tmux/tmux/releases/download/3.2a/tmux-3.2a.tar.gz
sudo tar -xzvf tmux-3.2a.tar.gz
cd tmux-3.2a
sudo ./configure
sudo make
sudo make install

# zsh
cd /usr/local/src/
curl -LO https://sourceforge.net/projects/zsh/files/zsh/5.8/zsh-5.8.tar.xz
sudo tar -xvf zsh-5.8.tar.xz
cd zsh-5.8.tar.xz
sudo ./configure --enable-multibyte
sudo make && make install

# npm
yum install -y nodejs npm
npm install -g n
n stable
exec $SHELL -l

# rbenv
sudo yum install -y git gcc gcc-c++ openssl-devel readline-devel
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv

echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zprofile
echo 'eval "$(rbenv init -)"' >> ~/.zprofile
source ~/.zprofile
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build

rbenv install {ruby version}
