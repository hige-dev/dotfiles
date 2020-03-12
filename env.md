# morokai
~/.vim/colorsにmolokai.vimを追加し、~/.vimrcを設定する。

```
$ mkdir ~/.vim
$ cd ~/.vim
$ mkdir colors

$ git clone https://github.com/tomasr/molokai
$ mv molokai/colors/molokai.vim ~/.vim/colors/

$ vi ~/.vimrc
```

# dein

```
・調べた結果、どうやら~/.cache/deinというところにdein.vimをインストールするのが通例の一つらしいので

#まず
$ mkdir -p ~/.cache/dein
#とした後に
$ cd ~/.cache/dein
#で移動してその状態で
$ curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
$ sh ./installer.sh ~/.cache/dein
#と打ってあげる
```
# rbenv

## centos7
```bash
$ sudo yum install -y git gcc gcc-c++ openssl-devel readline-devel

# rbenvリポジトリのクローン
$ git clone https://github.com/sstephenson/rbenv.git ~/.rbenv

# bash_profileにrbenvのパスを追加
$ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
$ echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
$ source ~/.bash_profile  # 設定内容を反映させるため.bash_profileを再読み込み

# rbenvのバージョンを確認
$ rbenv --version
```

# nvm
```bash
$ curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
$ source ~/.bashrc
$ nvm # 確認

$ nvm install v10.14.2
$ nvm use v10.14.2

$ curl -o- -L https://yarnpkg.com/install.sh | bash -s -- --version 1.13.0
$ source ~/.bashrc
```
