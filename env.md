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
