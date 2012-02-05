" vim:tabstop=2:shiftwidth=2:expandtab:foldmethod=marker:textwidth=79
" Vimwiki plugin file
" Author: Maxim Kim <habamax@gmail.com>
" Home: http://code.google.com/p/vimwiki/
" GetLatestVimScripts: 2226 1 :AutoInstall: vimwiki

if exists("loaded_vimwiki") || &cp
  finish
endif
let loaded_vimwiki = 1

let s:old_cpo = &cpo
set cpo&vim

" HELPER functions {{{
function! s:default(varname, value) "{{{
  if !exists('g:vimwiki_'.a:varname)
    let g:vimwiki_{a:varname} = a:value
  endif
endfunction "}}}

" return longest common path prefix of 2 given paths.
" '~/home/usrname/wiki', '~/home/usrname/wiki/shmiki' => '~/home/usrname/wiki'
function! s:path_common_pfx(path1, path2) "{{{
  let p1 = split(a:path1, '[/\\]', 1)
  let p2 = split(a:path2, '[/\\]', 1)

  let idx = 0
  let minlen = min([len(p1), len(p2)])
  while (idx < minlen) && (p1[idx] ==? p2[idx])
    let idx = idx + 1
  endwhile
  if idx == 0
    return ''
  else
    return join(p1[: idx-1], '/')
  endif
endfunction "}}}

function! s:find_wiki(path) "{{{
  " ensure that we are not fooled by a symbolic link
  let realpath = resolve(vimwiki#base#chomp_slash(a:path))
  let idx = 0
  while idx < len(g:vimwiki_list)
    let path = vimwiki#base#chomp_slash(expand(VimwikiGet('path', idx)))
    let path = vimwiki#base#path_norm(path)
    if s:path_common_pfx(path, realpath) == path
      return idx
    endif
    let idx += 1
  endwhile
  return -1
endfunction "}}}

function! s:setup_buffer_leave()"{{{
  if &filetype == 'vimwiki' && !exists("b:vimwiki_idx")
    let b:vimwiki_idx = g:vimwiki_current_idx
  endif

  " Set up menu
  if g:vimwiki_menu != ""
    exe 'nmenu disable '.g:vimwiki_menu.'.Table'
  endif
endfunction"}}}

function! s:setup_filetype() "{{{
  " Find what wiki current buffer belongs to.
  let path = expand('%:p:h')
  let ext = '.'.expand('%:e')
  let idx = s:find_wiki(path)

  if idx == -1 && g:vimwiki_global_ext == 0
    return
  endif

  set filetype=vimwiki
endfunction "}}}

function! s:setup_buffer_enter() "{{{
  if exists("b:vimwiki_idx")
    let g:vimwiki_current_idx = b:vimwiki_idx
  else
    " Find what wiki current buffer belongs to.
    " If wiki does not exist in g:vimwiki_list -- add new wiki there with
    " buffer's path and ext.
    " Else set g:vimwiki_current_idx to that wiki index.
    let path = expand('%:p:h')
    let ext = '.'.expand('%:e')
    let idx = s:find_wiki(path)

    " The buffer's file is not in the path and user do not want his wiki
    " extension to be global -- do not add new wiki.
    if idx == -1 && g:vimwiki_global_ext == 0
      return
    endif

    if idx == -1
      call add(g:vimwiki_list, {'path': path, 'ext': ext, 'temp': 1})
      let g:vimwiki_current_idx = len(g:vimwiki_list) - 1
    else
      let g:vimwiki_current_idx = idx
    endif

    let b:vimwiki_idx = g:vimwiki_current_idx
  endif

  " If you have
  "     au GUIEnter * VimwikiIndex
  " Then change it to
  "     au GUIEnter * nested VimwikiIndex
  if &filetype == ''
    set filetype=vimwiki
  endif

  " Update existed/non-existed links highlighting.
  call vimwiki#base#highlight_links()

  " Settings foldmethod, foldexpr and foldtext are local to window. Thus in a
  " new tab with the same buffer folding is reset to vim defaults. So we
  " insist vimwiki folding here.
  if g:vimwiki_folding == 1 && &fdm != 'expr'
    setlocal fdm=expr
    setlocal foldexpr=VimwikiFoldLevel(v:lnum)
    setlocal foldtext=VimwikiFoldText()
  endif

  " And conceal level too.
  if g:vimwiki_conceallevel && exists("+conceallevel")
    let &conceallevel = g:vimwiki_conceallevel
  endif

  " Set up menu
  if g:vimwiki_menu != ""
    exe 'nmenu enable '.g:vimwiki_menu.'.Table'
  endif
endfunction "}}}

" OPTION get/set functions {{{
" return value of option for current wiki or if second parameter exists for
" wiki with a given index.
function! VimwikiGet(option, ...) "{{{
  if a:0 == 0
    let idx = g:vimwiki_current_idx
  else
    let idx = a:1
  endif
  if !has_key(g:vimwiki_list[idx], a:option) &&
        \ has_key(s:vimwiki_defaults, a:option)
    if a:option == 'path_html'
      let g:vimwiki_list[idx][a:option] =
            \VimwikiGet('path', idx)[:-2].'_html/'
    else
      let g:vimwiki_list[idx][a:option] =
            \s:vimwiki_defaults[a:option]
    endif
  endif

  " if path's ending is not a / or \
  " then add it
  if a:option == 'path' || a:option == 'path_html'
    let p = g:vimwiki_list[idx][a:option]
    " resolve doesn't work quite right with symlinks ended with / or \
    let p = vimwiki#base#chomp_slash(p)
    let p = resolve(expand(p))
    let g:vimwiki_list[idx][a:option] = p.'/'
  endif

  return g:vimwiki_list[idx][a:option]
endfunction "}}}

" set option for current wiki or if third parameter exists for
" wiki with a given index.
function! VimwikiSet(option, value, ...) "{{{
  if a:0 == 0
    let idx = g:vimwiki_current_idx
  else
    let idx = a:1
  endif
  let g:vimwiki_list[idx][a:option] = a:value
endfunction "}}}
" }}}

" }}}

" CALLBACK function "{{{
" User can redefine it.
if !exists("*VimwikiWeblinkHandler") "{{{
  function VimwikiWeblinkHandler(weblink)
    if has("win32")
      "execute '!start ' . shellescape(a:weblink, 1)
      "http://vim.wikia.com/wiki/Opening_current_Vim_file_in_your_Windows_browser
      execute 'silent ! start "Title" /B ' . shellescape(a:weblink, 1)
    elseif has("macunix")
      execute '!open ' . shellescape(a:weblink, 1)
    else
      execute 'silent !xdg-open ' . shellescape(a:weblink, 1)
    endif
  endfunction
endif "}}}
" CALLBACK }}}

" DEFAULT wiki {{{
let s:vimwiki_defaults = {}
let s:vimwiki_defaults.path = '~/vimwiki/'
let s:vimwiki_defaults.path_html = '~/vimwiki_html/'
let s:vimwiki_defaults.css_name = 'style.css'
let s:vimwiki_defaults.index = 'index'
let s:vimwiki_defaults.ext = '.wiki'
let s:vimwiki_defaults.maxhi = 1
let s:vimwiki_defaults.syntax = 'default'

let s:vimwiki_defaults.template_path = ''
let s:vimwiki_defaults.template_default = ''
let s:vimwiki_defaults.template_ext = ''

let s:vimwiki_defaults.nested_syntaxes = {}
let s:vimwiki_defaults.auto_export = 0
" is wiki temporary -- was added to g:vimwiki_list by opening arbitrary wiki
" file.
let s:vimwiki_defaults.temp = 0

" diary
let s:vimwiki_defaults.diary_rel_path = 'diary/'
let s:vimwiki_defaults.diary_index = 'diary'
let s:vimwiki_defaults.diary_header = 'Diary'
let s:vimwiki_defaults.diary_sort = 'desc'

" Do not change this! Will wait till vim become more datetime awareable.
let s:vimwiki_defaults.diary_link_fmt = '%Y-%m-%d'

" custom_wiki2html
let s:vimwiki_defaults.custom_wiki2html = ''
"}}}

" DEFAULT options {{{
call s:default('list', [s:vimwiki_defaults])
if &encoding == 'utf-8'
  call s:default('upper', 'A-Z\u0410-\u042f')
  call s:default('lower', 'a-z\u0430-\u044f')
else
  call s:default('upper', 'A-Z')
  call s:default('lower', 'a-z')
endif
call s:default('stripsym', '_')
call s:default('badsyms', '')
call s:default('auto_checkbox', 1)
call s:default('use_mouse', 0)
call s:default('folding', 0)
call s:default('fold_trailing_empty_lines', 0)
call s:default('fold_lists', 0)
call s:default('menu', 'Vimwiki')
call s:default('global_ext', 1)
call s:default('hl_headers', 0)
call s:default('hl_cb_checked', 0)
call s:default('camel_case', 1)
call s:default('list_ignore_newline', 1)
call s:default('listsyms', ' .oOX')
call s:default('use_calendar', 1)
call s:default('table_auto_fmt', 1)
call s:default('w32_dir_enc', '')
call s:default('CJK_length', 0)
call s:default('dir_link', '')
call s:default('file_exts', 'pdf,txt,doc,rtf,xls,php,zip,rar,7z,html,gz')
call s:default('valid_html_tags', 'b,i,s,u,sub,sup,kbd,br,hr,div,center,strong,em')
call s:default('user_htmls', '')

call s:default('html_header_numbering', 0)
call s:default('html_header_numbering_sym', '')
call s:default('conceallevel', 2)
call s:default('url_mingain', 12)
call s:default('url_maxsave', 12)
call s:default('debug', 0)

call s:default('wikiword_escape_prefix', '!')

call s:default('diary_months', 
      \ {
      \ 1: 'January', 2: 'February', 3: 'March', 
      \ 4: 'April', 5: 'May', 6: 'June',
      \ 7: 'July', 8: 'August', 9: 'September',
      \ 10: 'October', 11: 'November', 12: 'December'
      \ })


call s:default('current_idx', 0)
"}}}


" LINKS: WikiLinks  {{{
let wword = '\C\<\%(['.g:vimwiki_upper.']['.g:vimwiki_lower.']\+\)\{2,}\>'

" 0. WikiWordURLs
" 0a) match WikiWordURLs
let g:vimwiki_rxWikiWord = g:vimwiki_wikiword_escape_prefix.'\@<!'.wword
let g:vimwiki_rxNoWikiWord = g:vimwiki_wikiword_escape_prefix.wword

"
let g:vimwiki_rxWikiLinkUrl = '[^|\]]\+'
let g:vimwiki_rxWikiLinkDescr = '[^\]]\+'
let g:vimwiki_rxWikiLinkPrefix = '\[\['
let g:vimwiki_rxWikiLinkSuffix = '\]\]'
"
" 1. [[URL]]
" 1a) match [[URL]]
let g:vimwiki_rxWikiLink1 = g:vimwiki_rxWikiLinkPrefix.
      \ g:vimwiki_rxWikiLinkUrl. g:vimwiki_rxWikiLinkSuffix
" 1b) match URL within [[URL]]
let g:vimwiki_rxWikiLinkMatchUrl1 = g:vimwiki_rxWikiLinkPrefix.
      \ '\zs'. g:vimwiki_rxWikiLinkUrl. '\ze'. g:vimwiki_rxWikiLinkSuffix
" 1c) match DESCRIPTION within [[URL]]
let g:vimwiki_rxWikiLinkMatchDescr1 = ''
"
" 2. [[URL][DESCRIPTION]]
let g:vimwiki_rxWikiLinkSeparator2 = '\]\['
" 2a) match [[URL][DESCRIPTION]]
let g:vimwiki_rxWikiLink2 = g:vimwiki_rxWikiLinkPrefix.
      \ g:vimwiki_rxWikiLinkUrl. g:vimwiki_rxWikiLinkSeparator2.
      \ g:vimwiki_rxWikiLinkDescr. g:vimwiki_rxWikiLinkSuffix
" 2b) match URL within [[URL][DESCRIPTION]]
let g:vimwiki_rxWikiLinkMatchUrl2 = g:vimwiki_rxWikiLinkPrefix.
      \ '\zs'. g:vimwiki_rxWikiLinkUrl. '\ze'. g:vimwiki_rxWikiLinkSeparator2.
      \ g:vimwiki_rxWikiLinkDescr. g:vimwiki_rxWikiLinkSuffix
" 2c) match DESCRIPTION within [[URL][DESCRIPTION]]
let g:vimwiki_rxWikiLinkMatchDescr2 = g:vimwiki_rxWikiLinkPrefix.
      \ g:vimwiki_rxWikiLinkUrl. g:vimwiki_rxWikiLinkSeparator2.
      \ '\zs'. g:vimwiki_rxWikiLinkDescr. '\ze'. g:vimwiki_rxWikiLinkSuffix
"
" 3. [[URL|DESCRIPTION]]
let g:vimwiki_rxWikiLinkSeparator3 = '|'
" 3a) match [[URL|DESCRIPTION]]
let g:vimwiki_rxWikiLink3 = g:vimwiki_rxWikiLinkPrefix.
      \ g:vimwiki_rxWikiLinkUrl. g:vimwiki_rxWikiLinkSeparator3.
      \ g:vimwiki_rxWikiLinkDescr. g:vimwiki_rxWikiLinkSuffix
" 3b) match URL within [[URL|DESCRIPTION]]
let g:vimwiki_rxWikiLinkMatchUrl3 = g:vimwiki_rxWikiLinkPrefix.
      \ '\zs'. g:vimwiki_rxWikiLinkUrl. '\ze'. g:vimwiki_rxWikiLinkSeparator3.
      \ g:vimwiki_rxWikiLinkDescr. g:vimwiki_rxWikiLinkSuffix
" 3c) match DESCRIPTION within [[URL|DESCRIPTION]]
let g:vimwiki_rxWikiLinkMatchDescr3 = g:vimwiki_rxWikiLinkPrefix.
      \ g:vimwiki_rxWikiLinkUrl. g:vimwiki_rxWikiLinkSeparator3.
      \ '\zs'. g:vimwiki_rxWikiLinkDescr. '\ze'. g:vimwiki_rxWikiLinkSuffix
"
" *. ANY wikilink
if g:vimwiki_camel_case
  " *a) match ANY wikilink
  let g:vimwiki_rxWikiLink = g:vimwiki_rxWikiLink3.'\|'.
        \ g:vimwiki_rxWikiLink2.'\|'.g:vimwiki_rxWikiLink1.'\|'.
        \ g:vimwiki_rxWikiWord
  " *b) match URL within ANY wikilink
  let g:vimwiki_rxWikiLinkMatchUrl = g:vimwiki_rxWikiLinkMatchUrl3.'\|'.
        \ g:vimwiki_rxWikiLinkMatchUrl2.'\|'.g:vimwiki_rxWikiLinkMatchUrl1.'\|'.
        \ g:vimwiki_rxWikiWord
else
  " *a) match ANY wikilink
  let g:vimwiki_rxWikiLink = g:vimwiki_rxWikiLink3.'\|'.
        \ g:vimwiki_rxWikiLink2.'\|'.g:vimwiki_rxWikiLink1
  " *b) match URL within ANY wikilink
  let g:vimwiki_rxWikiLinkMatchUrl = g:vimwiki_rxWikiLinkMatchUrl3.'\|'.
        \ g:vimwiki_rxWikiLinkMatchUrl2.'\|'.g:vimwiki_rxWikiLinkMatchUrl1
endif
" *c) match DESCRIPTION within ANY wikilink
let g:vimwiki_rxWikiLinkMatchDescr = g:vimwiki_rxWikiLinkMatchDescr3.'\|'.
      \ g:vimwiki_rxWikiLinkMatchDescr2.'\|'.g:vimwiki_rxWikiLinkMatchDescr1
"}}}

"
" LINKS: WebLinks {{{
" match URL for common protocols;  XXX ms-help ??
" see http://en.wikipedia.org/wiki/URI_scheme  http://tools.ietf.org/html/rfc3986
let g:vimwiki_rxWebProtocols = ''.
    \  '\%('.
      \  '\%('.
        \  '\%(https\?\|file\|ftp\|gopher\|telnet\|nntp\|ldap\|rsync\|imap\|pop\|ircs\?\|cvs\|svn\|svn+ssh\|git\|ssh\|fish\|sftp\|notes\|ms-help\):'.
        \  '\%(\%(//\)\|\%(\\\\\)\)'.
      \  '\)'.
      \  '\|'.
      \  '\%(mailto\|news\|xmpp\|sips\?\|doi\|urn\|tel\):'.
    \  '\)'
let g:vimwiki_rxWeblinkUrl = g:vimwiki_rxWebProtocols .
    \  '\S\{-1,}\%(([^ \t()]*)\)\=' . '\%([),:;.!?]\=\%([ \t]\|$\)\)\@='
" free-standing links: keep URL UR(L) strip trailing punct: URL; URL) UR(L)) 
let g:vimwiki_rxWeblinkUrl3 = g:vimwiki_rxWebProtocols .
    \  '[^ \]]\+' . '\%( *\|]\)\@='
" ending with <SP> or ] : [URL descr] or [URL] or [URL ]
let g:vimwiki_rxWeblinkUrl2 = g:vimwiki_rxWebProtocols .
    \  '\S\{-1,}\%(([^ \t()]*)\)\=' . ' *)\@='
" ending with ) : (URL) or (URL ) or (UR(L)) or (UR(L) )


" " Url Character Set
" let g:vimwiki_rxWebUrlChar = '[^| \t]'
" let g:vimwiki_rxWeblinkUrl = ....
"   \  g:vimwiki_rxWebUrlChar.'\{-1,}'. '([^ \t()]*)' 
"   \  g:vimwiki_rxWebUrlChar.'\+'. '[.,;!?\]()]\@<!' 

" FIXME all submatches can be done with "numbered" \( \) groups
" 0. URL
let g:vimwiki_rxWeblink0 = '[\["(|]\@<!'. g:vimwiki_rxWeblinkUrl
" 0a) match URL within URL
let g:vimwiki_rxWeblinkMatchUrl0 = g:vimwiki_rxWeblinkUrl
let g:vimwiki_rxWeblinkMatchDescr0 = ''
"
" 1. "DESCRIPTION(OPTIONAL)":URL
let g:vimwiki_rxWeblinkPrefix1 = '"'
let g:vimwiki_rxWeblinkDescr1 = '\%([^"()]\+\%((\%([^()]\+\))\)\?\)\?'
let g:vimwiki_rxWeblinkSeparator1 = '":'
let g:vimwiki_rxWeblinkSuffix1 = ''
" 1a) match "DESCRIPTION(OPTIONAL)":URL
let g:vimwiki_rxWeblink1 = g:vimwiki_rxWeblinkPrefix1.
      \ g:vimwiki_rxWeblinkDescr1. g:vimwiki_rxWeblinkSeparator1.
      \ g:vimwiki_rxWeblinkUrl. g:vimwiki_rxWeblinkSuffix1
" 1b) match URL within "DESCRIPTION(OPTIONAL)":URL
let g:vimwiki_rxWeblinkMatchUrl1 = g:vimwiki_rxWeblinkPrefix1.
      \ g:vimwiki_rxWeblinkDescr1. g:vimwiki_rxWeblinkSeparator1.
      \ '\zs'. g:vimwiki_rxWeblinkUrl. '\ze'. g:vimwiki_rxWeblinkSuffix1
" 1c) match DESCRIPTION(OPTIONAL) within "DESCRIPTION(OPTIONAL)":URL
let g:vimwiki_rxWeblinkMatchDescr1 = g:vimwiki_rxWeblinkPrefix1.
      \ '\zs'. g:vimwiki_rxWeblinkDescr1. '\ze' . g:vimwiki_rxWeblinkSeparator1.
      \ g:vimwiki_rxWeblinkUrl. g:vimwiki_rxWeblinkSuffix1
"
" 2. [DESCRIPTION](URL)   N.b. the [] do not indicate an optional component
let g:vimwiki_rxWeblinkPrefix2 = '[\[\]]\@<!\[' 
let g:vimwiki_rxWeblinkDescr2 = '\%([^\[\]]*\)'
let g:vimwiki_rxWeblinkSeparator2 = '\] *('
let g:vimwiki_rxWeblinkSuffix2 = ')'
" 2a) match [DESCRIPTION](URL)
let g:vimwiki_rxWeblink2 = g:vimwiki_rxWeblinkPrefix2.
      \ g:vimwiki_rxWeblinkDescr2. g:vimwiki_rxWeblinkSeparator2.
      \ g:vimwiki_rxWeblinkUrl2. g:vimwiki_rxWeblinkSuffix2
" 2b) match URL within [DESCRIPTION](URL)
let g:vimwiki_rxWeblinkMatchUrl2 = g:vimwiki_rxWeblinkPrefix2.
      \ g:vimwiki_rxWeblinkDescr2. g:vimwiki_rxWeblinkSeparator2.
      \ '\zs'. g:vimwiki_rxWeblinkUrl2. '\ze'. g:vimwiki_rxWeblinkSuffix2
" 2c) match DESCRIPTION within [DESCRIPTION](URL)
let g:vimwiki_rxWeblinkMatchDescr2 = g:vimwiki_rxWeblinkPrefix2.
      \ '\zs'. g:vimwiki_rxWeblinkDescr2. '\ze' . g:vimwiki_rxWeblinkSeparator2.
      \ g:vimwiki_rxWeblinkUrl2. g:vimwiki_rxWeblinkSuffix2
"
" 3. [URL DESCRIPTION]
" 2012-02-04 DONE - FIXME not starting with \[\[  ? 
let g:vimwiki_rxWeblinkPrefix3 = '[\[\]]\@<!\['
let g:vimwiki_rxWeblinkSeparator3 = '\s*'
let g:vimwiki_rxWeblinkDescr3 = '\%([^\[\]]*\)'
let g:vimwiki_rxWeblinkSuffix3 = '\]'
" 3a) match [URL DESCRIPTION]
let g:vimwiki_rxWeblink3 = g:vimwiki_rxWeblinkPrefix3.
      \ g:vimwiki_rxWeblinkUrl3. g:vimwiki_rxWeblinkSeparator3. 
      \ g:vimwiki_rxWeblinkDescr3. g:vimwiki_rxWeblinkSuffix3
" 3b) match URL within [URL DESCRIPTION]
let g:vimwiki_rxWeblinkMatchUrl3 = g:vimwiki_rxWeblinkPrefix3.
      \ '\zs'. g:vimwiki_rxWeblinkUrl3. '\ze'. g:vimwiki_rxWeblinkSeparator3. 
      \ g:vimwiki_rxWeblinkDescr3. g:vimwiki_rxWeblinkSuffix3
" 3c) match DESCRIPTION within [URL DESCRIPTION]
let g:vimwiki_rxWeblinkMatchDescr3 = g:vimwiki_rxWeblinkPrefix3.
      \ g:vimwiki_rxWeblinkUrl3. g:vimwiki_rxWeblinkSeparator3. 
      \ '\zs'. g:vimwiki_rxWeblinkDescr3. '\ze'. g:vimwiki_rxWeblinkSuffix3
"
" *. ANY weblink
" *a) match ANY weblink
let g:vimwiki_rxWeblink = g:vimwiki_rxWeblink2.'\|'.
        \ g:vimwiki_rxWeblink3.'\|'. g:vimwiki_rxWeblink1.'\|'.
        \ g:vimwiki_rxWeblink0
" *b) match URL within ANY weblink
let g:vimwiki_rxWeblinkMatchUrl = g:vimwiki_rxWeblinkMatchUrl2.'\|'.
        \ g:vimwiki_rxWeblinkMatchUrl3.'\|'. g:vimwiki_rxWeblinkMatchUrl1.'\|'.
        \ g:vimwiki_rxWeblinkMatchUrl0
" *c) match DESCRIPTION within ANY weblink
let g:vimwiki_rxWeblinkMatchDescr = g:vimwiki_rxWeblinkMatchDescr2.'\|'.
        \ g:vimwiki_rxWeblinkMatchDescr3.'\|'. g:vimwiki_rxWeblinkMatchDescr1.'\|'.
        \ g:vimwiki_rxWeblinkMatchDescr0
"}}}


" characters, excluding' ', '\t', or '[' following ']'
let g:vimwiki_rxImageUrlChar = '\%([^| \t\[]\|\]\@<!\[\)'
"
" LINKS: Images {{{
" match URL
let g:vimwiki_rxImageUrl = ''.
      \'\%('.
        \'\%(https\?\|file\|ftp\|gopher\|telnet\|nntp\|ldap\|rsync\|imap\|pop\|ircs\?\|cvs\|svn\|svn+ssh\|git\|ssh\|fish\|sftp\|notes\|ms-help\):'.
        \'\%(\%(//\)\|\%(\\\\\)\)'.
      \'\)\?'.
      \'\%('.
        \'\%('. g:vimwiki_rxImageUrlChar.'\{-1,}'. '([^ \t()]*)'. '\)'.
        \'\|'.
        \'\%('. g:vimwiki_rxImageUrlChar.'\+'. '[,;!?\]()]\@<!'. '\)'.
      \'\)'.
      \'\%('.
        \'\%(jpg\|jpeg\|png\|gif\)'.
        \'\|'.
        \'\%(JPG\|JPEG\|PNG\|GIF\)'.
      \'\)'

"
let g:vimwiki_rxImagePrefix = '\[\['
let g:vimwiki_rxImageSuffix = '\]\]'
"
" " 0. URL
" " let g:vimwiki_rxImage0 = g:vimwiki_rxImageUrl
" " " 0a) match URL within URL
" " let g:vimwiki_rxImageMatchUrl0 = g:vimwiki_rxImageUrl
" " let g:vimwiki_rxImageMatchDescr0 = ''
" " let g:vimwiki_rxImageMatchStyle0 = ''
"
" " 1. [[IMGURL]]
" " 1a) match [[IMGURL]]
" let g:vimwiki_rxImage1 = g:vimwiki_rxImagePrefix.
"       \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSuffix
" " 1b) match IMGURL within [[IMGURL]]
" let g:vimwiki_rxImageMatchUrl1 = g:vimwiki_rxImagePrefix.
"       \ '\zs'. g:vimwiki_rxImageUrl. '\ze'. g:vimwiki_rxImageSuffix
" " 1c) match DESCRIPTION within [[IMGURL]]
" let g:vimwiki_rxImageMatchDescr1 = ''
" " 1d) match STYLE within [[IMGURL]]
" let g:vimwiki_rxImageMatchStyle1 = ''
"
" 2. [[IMGURL][DESCRIPTION][STYLE]]
let g:vimwiki_rxImageDescr2 = '[^\]]*'
let g:vimwiki_rxImageSeparator2 = '\%(\]\[\)\?'
let g:vimwiki_rxImageStyle2 = '[^\]]*'
" 2a) match [[IMGURL][DESCRIPTION][STYLE]]
let g:vimwiki_rxImage2 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageDescr2. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageStyle2. g:vimwiki_rxImageSuffix
" 2b) match IMGURL within [[IMGURL][DESCRIPTION][STYLE]]
let g:vimwiki_rxImageMatchUrl2 = g:vimwiki_rxImagePrefix.
      \ '\zs'. g:vimwiki_rxImageUrl. '\ze'. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageDescr2. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageStyle2. g:vimwiki_rxImageSuffix
" 2c) match DESCRIPTION within [[IMGURL][DESCRIPTION][STYLE]]
let g:vimwiki_rxImageMatchDescr2 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator2.
      \ '\zs'. g:vimwiki_rxImageDescr2. '\ze'. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageStyle2. g:vimwiki_rxImageSuffix
" 2d) match STYLE within [[IMGURL][DESCRIPTION][STYLE]]
let g:vimwiki_rxImageMatchStyle2 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator2.
      \ g:vimwiki_rxImageDescr2. g:vimwiki_rxImageSeparator2.
      \ '\zs'. g:vimwiki_rxImageStyle2. '\ze'. g:vimwiki_rxImageSuffix
"
" 3. [[IMGURL|DESCRIPTION|STYLE]]
let g:vimwiki_rxImageDescr3 = '[^|\]]*'
let g:vimwiki_rxImageSeparator3 = '|\?'
let g:vimwiki_rxImageStyle3 = '[^|\]]*'
" 3a) match [[IMGURL|DESCRIPTION|STYLE]]
let g:vimwiki_rxImage3 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageDescr3. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageStyle3. g:vimwiki_rxImageSuffix
" 3b) match IMGURL within [[IMGURL|DESCRIPTION|STYLE]]
let g:vimwiki_rxImageMatchUrl3 = g:vimwiki_rxImagePrefix.
      \ '\zs'. g:vimwiki_rxImageUrl. '\ze'. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageDescr3. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageStyle3. g:vimwiki_rxImageSuffix
" 3c) match DESCRIPTION within [[IMGURL|DESCRIPTION|STYLE]]
let g:vimwiki_rxImageMatchDescr3 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator3.
      \ '\zs'. g:vimwiki_rxImageDescr3. '\ze'. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageStyle3. g:vimwiki_rxImageSuffix
" 3d) match STYLE within [[IMGURL|DESCRIPTION|STYLE]]
let g:vimwiki_rxImageMatchStyle3 = g:vimwiki_rxImagePrefix.
      \ g:vimwiki_rxImageUrl. g:vimwiki_rxImageSeparator3.
      \ g:vimwiki_rxImageDescr3. g:vimwiki_rxImageSeparator3.
      \ '\zs'. g:vimwiki_rxImageStyle3. '\ze'. g:vimwiki_rxImageSuffix
"
" *. ANY Image
" *a) match ANY Image
let g:vimwiki_rxImage = g:vimwiki_rxImage3.'\|'.
        \ g:vimwiki_rxImage2 " .'\|'.g:vimwiki_rxImage0
" *b) match IMGURL within ANY Image
let g:vimwiki_rxImageMatchUrl = g:vimwiki_rxImageMatchUrl3.'\|'.
        \ g:vimwiki_rxImageMatchUrl2 " .'\|'.g:vimwiki_rxImageMatchUrl0
" *c) match DESCRIPTION within ANY Image
let g:vimwiki_rxImageMatchDescr = g:vimwiki_rxImageMatchDescr3.'\|'.
        \ g:vimwiki_rxImageMatchDescr2 " .'\|'.g:vimwiki_rxImageMatchDescr0
" *d) match STYLE within ANY Image
let g:vimwiki_rxImageMatchStyle = g:vimwiki_rxImageMatchStyle3.'\|'.
        \ g:vimwiki_rxImageMatchStyle2 " .'\|'.g:vimwiki_rxImageMatchStyle0
"}}}


" AUTOCOMMANDS for all known wiki extensions {{{
" Getting all extensions that different wikies could have
let extensions = {}
for wiki in g:vimwiki_list
  if has_key(wiki, 'ext')
    let extensions[wiki.ext] = 1
  else
    let extensions['.wiki'] = 1
  endif
endfor

augroup filetypedetect
  " clear FlexWiki's stuff
  au! * *.wiki
augroup end

augroup vimwiki
  autocmd!
  for ext in keys(extensions)
    exe 'autocmd BufWinEnter *'.ext.' call s:setup_buffer_enter()'
    exe 'autocmd BufLeave,BufHidden *'.ext.' call s:setup_buffer_leave()'
    exe 'autocmd BufNewFile,BufRead, *'.ext.' call s:setup_filetype()'

    " ColorScheme could have or could have not a
    " VimwikiHeader1..VimwikiHeader6 highlight groups. We need to refresh
    " syntax after colorscheme change.
    exe 'autocmd ColorScheme *'.ext.' syntax enable'.
          \ ' | call vimwiki#base#highlight_links()'

    " Format tables when exit from insert mode. Do not use textwidth to
    " autowrap tables.
    if g:vimwiki_table_auto_fmt
      exe 'autocmd InsertLeave *'.ext.' call vimwiki#tbl#format(line("."))'
      exe 'autocmd InsertEnter *'.ext.' call vimwiki#tbl#reset_tw(line("."))'
    endif
  endfor
augroup END
"}}}

" COMMANDS {{{
command! VimwikiUISelect call vimwiki#base#ui_select()
command! -count VimwikiIndex
      \ call vimwiki#base#goto_index(v:count1)
command! -count VimwikiTabIndex tabedit <bar>
      \ call vimwiki#base#goto_index(v:count1)

command! -count VimwikiDiaryIndex
      \ call vimwiki#diary#goto_index(v:count1)
command! -count VimwikiMakeDiaryNote
      \ call vimwiki#diary#make_note(v:count1)
command! -count VimwikiTabMakeDiaryNote tabedit <bar>
      \ call vimwiki#diary#make_note(v:count1)
"}}}

" MAPPINGS {{{
if !hasmapto('<Plug>VimwikiIndex')
  nmap <silent><unique> <Leader>ww <Plug>VimwikiIndex
endif
nnoremap <unique><script> <Plug>VimwikiIndex :VimwikiIndex<CR>

if !hasmapto('<Plug>VimwikiTabIndex')
  nmap <silent><unique> <Leader>wt <Plug>VimwikiTabIndex
endif
nnoremap <unique><script> <Plug>VimwikiTabIndex :VimwikiTabIndex<CR>

if !hasmapto('<Plug>VimwikiUISelect')
  nmap <silent><unique> <Leader>ws <Plug>VimwikiUISelect
endif
nnoremap <unique><script> <Plug>VimwikiUISelect :VimwikiUISelect<CR>

if !hasmapto('<Plug>VimwikiDiaryIndex')
  nmap <silent><unique> <Leader>wi <Plug>VimwikiDiaryIndex
endif
nnoremap <unique><script> <Plug>VimwikiDiaryIndex :VimwikiDiaryIndex<CR>

if !hasmapto('<Plug>VimwikiMakeDiaryNote')
  nmap <silent><unique> <Leader>w<Leader>w <Plug>VimwikiMakeDiaryNote
endif
nnoremap <unique><script> <Plug>VimwikiMakeDiaryNote :VimwikiMakeDiaryNote<CR>

if !hasmapto('<Plug>VimwikiTabMakeDiaryNote')
  nmap <silent><unique> <Leader>w<Leader>t <Plug>VimwikiTabMakeDiaryNote
endif
nnoremap <unique><script> <Plug>VimwikiTabMakeDiaryNote
      \ :VimwikiTabMakeDiaryNote<CR>

"}}}

" MENU {{{
function! s:build_menu(topmenu)
  let idx = 0
  while idx < len(g:vimwiki_list)
    let norm_path = fnamemodify(VimwikiGet('path', idx), ':h:t')
    let norm_path = escape(norm_path, '\ \.')
    execute 'menu '.a:topmenu.'.Open\ index.'.norm_path.
          \ ' :call vimwiki#base#goto_index('.(idx + 1).')<CR>'
    execute 'menu '.a:topmenu.'.Open/Create\ diary\ note.'.norm_path.
          \ ' :call vimwiki#diary#make_note('.(idx + 1).')<CR>'
    let idx += 1
  endwhile
endfunction

function! s:build_table_menu(topmenu)
  exe 'menu '.a:topmenu.'.-Sep- :'
  exe 'menu '.a:topmenu.'.Table.Create\ (enter\ cols\ rows) :VimwikiTable '
  exe 'nmenu '.a:topmenu.'.Table.Format<tab>gqq gqq'
  exe 'nmenu '.a:topmenu.'.Table.Move\ column\ left<tab><A-Left> :VimwikiTableMoveColumnLeft<CR>'
  exe 'nmenu '.a:topmenu.'.Table.Move\ column\ right<tab><A-Right> :VimwikiTableMoveColumnRight<CR>'
  exe 'nmenu disable '.a:topmenu.'.Table'
endfunction

if !empty(g:vimwiki_menu)
  call s:build_menu(g:vimwiki_menu)
  call s:build_table_menu(g:vimwiki_menu)
endif
" }}}

" CALENDAR Hook "{{{
if g:vimwiki_use_calendar
  let g:calendar_action = 'vimwiki#diary#calendar_action'
  let g:calendar_sign = 'vimwiki#diary#calendar_sign'
endif
"}}}

let &cpo = s:old_cpo
