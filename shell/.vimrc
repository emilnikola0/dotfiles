" ~/.vimrc — sensible defaults
" Copy to your home directory: cp .vimrc ~/.vimrc

" ---- Line numbers ----
set number              " show absolute line number on current line
set relativenumber      " show relative numbers on all other lines (great for jumps like 5j/3k)

" ---- General usability ----
set nocompatible         " use Vim defaults instead of strict vi compatibility
syntax on                 " enable syntax highlighting
filetype plugin indent on " enable filetype detection, plugins, and indent rules
set encoding=utf-8

" ---- Search ----
set incsearch            " show matches as you type
set hlsearch             " highlight all matches
set ignorecase           " case-insensitive search...
set smartcase            " ...unless you type an uppercase letter

" ---- Indentation ----
set tabstop=4            " width of a tab character
set shiftwidth=4         " width used for autoindent
set softtabstop=4        " spaces inserted when pressing Tab
set expandtab            " convert tabs to spaces
set autoindent
set smartindent

" ---- Interface ----
set cursorline           " highlight the current line
set showcmd              " show incomplete commands in bottom bar
set wildmenu             " visual autocomplete for command menu
set ruler                " show cursor position in status bar
set laststatus=2         " always show the status line
set scrolloff=8          " keep 8 lines visible above/below cursor
set signcolumn=yes       " keep sign column open (avoids text shifting)

" ---- Editing behavior ----
set backspace=indent,eol,start   " make backspace behave sanely
set clipboard=unnamedplus        " use system clipboard for yank/paste
set mouse=a                      " enable mouse support (scrolling, clicking, resizing)
set undofile                     " persistent undo across sessions
set undodir=~/.vim/undodir

" ---- Backup/swap files ----
set noswapfile
set nobackup
set nowritebackup

" ---- Splits open in a more natural direction ----
set splitright
set splitbelow

" ---- Misc ----
set wrap                 " wrap long lines
set linebreak            " wrap at word boundaries, not mid-word
set title                " set terminal title to filename
set confirm              " ask for confirmation instead of failing on unsaved changes

" ---- Key mappings (optional, comment out if unwanted) ----
" Clear search highlight with Escape
nnoremap <silent> <Esc> :nohlsearch<CR><Esc>

" Toggle line numbers with F2
nnoremap <F2> :set nu! rnu!<CR>
