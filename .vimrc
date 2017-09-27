" Settings
syntax on               "turn on syntax highlighting
set tabstop=4           "visual spaces per tab
set shiftwidth=4        "spaces to shift
set softtabstop=4       "while editing tabs are 4 spaces
set expandtab           "tabs are spaces
set noshowmatch         "disable matching brackets
set autoindent          "indentations on
set cindent             "indentations for c
set nocompatible        "don't pretend to be vi
set number              "line numbers
set relativenumber      "relative numbering
set hlsearch            "highlight search results
set incsearch           "incremental searches

" Colors
colorscheme ron
highlight linenr ctermfg=darkgrey
highlight cursorlinenr ctermfg=darkgrey

" Jump to last position in file
au BufReadPost *
\ if line("'\"") > 1 && line("'\"") <= line("$") && &ft !~# 'commit'
\ |   exe "normal! g`\""
\ | endif
