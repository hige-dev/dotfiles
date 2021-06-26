call plug#begin("~/.vim/plugged")
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'Shougo/unite.vim' " :Unite colorschme -auto-preview
Plug 'ujihisa/unite-colorscheme'
Plug 'tomasr/molokai', {'do': 'cp colors/* ~/.vim/colors'}
Plug 'skanehira/translate.vim' " :Translate
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
call plug#end()

" git clone https://github.com/ctrlpvim/ctrlp.vim ~/.vim/bundle/ctrlp.vim
set runtimepath^=~/.vim/bundle/ctrlp.vim

colorscheme molokai
let g:airline_solarized_bg='dark'

set encoding=utf-8
set fileencoding=utf-8 " 保存時の文字コード
set fileencodings=ucs-boms,utf-8,euc-jp,cp932 " 読み込み時の文字コードの自動判別. 左側が優先される
set fileformats=unix,dos,mac " 改行コードの自動判別. 左側が優先される
set ambiwidth=double " □や○文字が崩れる問題を解決
set expandtab " タブ入力を複数の空白入力に置き換える
set tabstop=2 " 画面上でタブ文字が占める幅
set softtabstop=2 " 連続した空白に対してタブキーやバックスペースキーでカーソルが動く幅
set autoindent " 改行時に前の行のインデントを継続する
set smartindent " 改行時に前の行の構文をチェックし次の行のインデントを増減する
set shiftwidth=2 " smartindentで増減する幅
set incsearch " インクリメンタルサーチ. １文字入力毎に検索を行う
set ignorecase " 検索パターンに大文字小文字を区別しない
set smartcase " 検索パターンに大文字を含んでいたら大文字小文字を区別する
set hlsearch " 検索結果をハイライト
set cursorline " カーソルラインをハイライト
set showmatch " 括弧の対応関係を一瞬表示する
set mouse=a
set nonu
set wildmenu " コマンドモードの補完
set history=5000 " 保存するコマンド履歴の数
set noswapfile
set backspace=indent,eol,start
set statusline=%F " ファイル名表示
set statusline+=%m " 変更チェック表示
set statusline+=%r " 読み込み専用かどうか表示
set statusline+=%h " ヘルプページなら[HELP]と表示
set statusline+=%w " プレビューウインドウなら[Prevew]と表示
set statusline+=%= " これ以降は右寄せ表示
set statusline+=[LOW=%l/%L] " 現在行数/全行数
set laststatus=2 " ステータスラインを常に表示(0:表示しない、1:2つ以上ウィンドウがある時だけ表示)
nnoremap ^] <Nop>
set clipboard+=unnamed

