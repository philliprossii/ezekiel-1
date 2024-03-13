" Tests for diff mode

source shared.vim
source screendump.vim
source check.vim

func Test_diff_fold_sync()
  enew!
  let g:update_count = 0
  au DiffUpdated * let g:update_count += 1

  let l = range(50)
  call setline(1, l)
  diffthis
  let winone = win_getid()
  new
  let l[25] = 'diff'
  call setline(1, l)
  diffthis
  let wintwo = win_getid()
  " line 15 is inside the closed fold
  call assert_equal(19, foldclosedend(10))
  call win_gotoid(winone)
  call assert_equal(19, foldclosedend(10))
  " open the fold
  normal zv
  call assert_equal(-1, foldclosedend(10))
  " fold in other window must have opened too
  call win_gotoid(wintwo)
  call assert_equal(-1, foldclosedend(10))

  " cursor position is in sync
  normal 23G
  call win_gotoid(winone)
  call assert_equal(23, getcurpos()[1])

  " depending on how redraw is done DiffUpdated may be triggered once or twice
  call assert_inrange(1, 2, g:update_count)
  au! DiffUpdated

  windo diffoff
  close!
  set nomodified
endfunc

func Test_vert_split()
  set diffopt=filler
  call Common_vert_split()
  set diffopt&
endfunc

func Test_vert_split_internal()
  set diffopt=internal,filler
  call Common_vert_split()
  set diffopt&
endfunc

func Common_vert_split()
  " Disable the title to avoid xterm keeping the wrong one.
  set notitle noicon
  new
  let l = ['1 aa', '2 bb', '3 cc', '4 dd', '5 ee']
  call setline(1, l)
  w! Xtest
  normal dd
  $
  put
  normal kkrXoxxx
  w! Xtest2
  file Nop
  normal ggoyyyjjjozzzz
  set foldmethod=marker foldcolumn=4
  call assert_equal(0, &diff)
  call assert_equal('marker', &foldmethod)
  call assert_equal(4, &foldcolumn)
  call assert_equal(0, &scrollbind)
  call assert_equal(0, &cursorbind)
  call assert_equal(1, &wrap)

  vert diffsplit Xtest
  vert diffsplit Xtest2
  call assert_equal(1, &diff)
  call assert_equal('diff', &foldmethod)
  call assert_equal(2, &foldcolumn)
  call assert_equal(1, &scrollbind)
  call assert_equal(1, &cursorbind)
  call assert_equal(0, &wrap)

  let diff_fdm = &fdm
  let diff_fdc = &fdc
  " repeat entering diff mode here to see if this saves the wrong settings
  diffthis
  " jump to second window for a moment to have filler line appear at start of
  " first window
  wincmd w
  normal gg
  wincmd p
  normal gg
  call assert_equal(2, winline())
  normal j
  call assert_equal(4, winline())
  normal j
  call assert_equal(5, winline())
  normal j
  call assert_equal(6, winline())
  normal j
  call assert_equal(8, winline())
  normal j
  call assert_equal(9, winline())

  wincmd w
  normal gg
  call assert_equal(1, winline())
  normal j
  call assert_equal(2, winline())
  normal j
  call assert_equal(4, winline())
  normal j
  call assert_equal(5, winline())
  normal j
  call assert_equal(8, winline())

  wincmd w
  normal gg
  call assert_equal(2, winline())
  normal j
  call assert_equal(3, winline())
  normal j
  call assert_equal(4, winline())
  normal j
  call assert_equal(5, winline())
  normal j
  call assert_equal(6, winline())
  normal j
  call assert_equal(7, winline())
  normal j
  call assert_equal(8, winline())

  " Test diffoff
  diffoff!
  1wincmd w
  let &diff = 1
  let &fdm = diff_fdm
  let &fdc = diff_fdc
  4wincmd w
  diffoff!
  1wincmd w
  call assert_equal(0, &diff)
  call assert_equal('marker', &foldmethod)
  call assert_equal(4, &foldcolumn)
  call assert_equal(0, &scrollbind)
  call assert_equal(0, &cursorbind)
  call assert_equal(1, &wrap)

  wincmd w
  call assert_equal(0, &diff)
  call assert_equal('marker', &foldmethod)
  call assert_equal(4, &foldcolumn)
  call assert_equal(0, &scrollbind)
  call assert_equal(0, &cursorbind)
  call assert_equal(1, &wrap)

  wincmd w
  call assert_equal(0, &diff)
  call assert_equal('marker', &foldmethod)
  call assert_equal(4, &foldcolumn)
  call assert_equal(0, &scrollbind)
  call assert_equal(0, &cursorbind)
  call assert_equal(1, &wrap)

  call delete('Xtest')
  call delete('Xtest2')
  windo bw!
endfunc

func Test_filler_lines()
  " Test that diffing shows correct filler lines
  enew!
  put =range(4,10)
  1d _
  vnew
  put =range(1,10)
  1d _
  windo diffthis
  wincmd h
  call assert_equal(1, line('w0'))
  unlet! diff_fdm diff_fdc
  windo diffoff
  bwipe!
  enew!
endfunc

func Test_diffget_diffput()
  enew!
  let l = range(50)
  call setline(1, l)
  call assert_fails('diffget', 'E99:')
  diffthis
  call assert_fails('diffget', 'E100:')
  new
  let l[10] = 'one'
  let l[20] = 'two'
  let l[30] = 'three'
  let l[40] = 'four'
  call setline(1, l)
  diffthis
  call assert_equal('one', getline(11))
  11diffget
  call assert_equal('10', getline(11))
  21diffput
  wincmd w
  call assert_equal('two', getline(21))
  normal 31Gdo
  call assert_equal('three', getline(31))
  call assert_equal('40', getline(41))
  normal 41Gdp
  wincmd w
  call assert_equal('40', getline(41))
  new
  diffthis
  call assert_fails('diffget', 'E101:')

  windo diffoff
  %bwipe!
endfunc

" Test putting two changes from one buffer to another
func Test_diffput_two()
  new a
  let win_a = win_getid()
  call setline(1, range(1, 10))
  diffthis
  new b
  let win_b = win_getid()
  call setline(1, range(1, 10))
  8del
  5del
  diffthis
  call win_gotoid(win_a)
  %diffput
  call win_gotoid(win_b)
  call assert_equal(map(range(1, 10), 'string(v:val)'), getline(1, '$'))
  bwipe! a
  bwipe! b
endfunc

" Test for :diffget/:diffput with a range that is inside a diff chunk
func Test_diffget_diffput_range()
  call setline(1, range(1, 10))
  new
  call setline(1, range(11, 20))
  windo diffthis
  3,5diffget
  call assert_equal(['13', '14', '15'], getline(3, 5))
  call setline(1, range(1, 10))
  4,8diffput
  wincmd p
  call assert_equal(['13', '4', '5', '6', '7', '8', '19'], getline(3, 9))
  %bw!
endfunc

" Test for :diffget/:diffput with an empty buffer and a non-empty buffer
func Test_diffget_diffput_empty_buffer()
  %d _
  new
  call setline(1, 'one')
  windo diffthis
  diffget
  call assert_equal(['one'], getline(1, '$'))
  %d _
  diffput
  wincmd p
  call assert_equal([''], getline(1, '$'))
  %bw!
endfunc

" :diffput and :diffget completes names of buffers which
" are in diff mode and which are different than current buffer.
" No completion when the current window is not in diff mode.
func Test_diffget_diffput_completion()
  e            Xdiff1 | diffthis
  botright new Xdiff2
  botright new Xdiff3 | split | diffthis
  botright new Xdiff4 | diffthis

  wincmd t
  call assert_equal('Xdiff1', bufname('%'))
  call feedkeys(":diffput \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput Xdiff3 Xdiff4', @:)
  call feedkeys(":diffget \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget Xdiff3 Xdiff4', @:)
  call assert_equal(['Xdiff3', 'Xdiff4'], getcompletion('', 'diff_buffer'))

  " Xdiff2 is not in diff mode, so no completion for :diffput, :diffget
  wincmd j
  call assert_equal('Xdiff2', bufname('%'))
  call feedkeys(":diffput \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput ', @:)
  call feedkeys(":diffget \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget ', @:)
  call assert_equal([], getcompletion('', 'diff_buffer'))

  " Xdiff3 is split in 2 windows, only the top one is in diff mode.
  " So completion of :diffput :diffget only happens in the top window.
  wincmd j
  call assert_equal('Xdiff3', bufname('%'))
  call assert_equal(1, &diff)
  call feedkeys(":diffput \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput Xdiff1 Xdiff4', @:)
  call feedkeys(":diffget \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget Xdiff1 Xdiff4', @:)
  call assert_equal(['Xdiff1', 'Xdiff4'], getcompletion('', 'diff_buffer'))

  wincmd j
  call assert_equal('Xdiff3', bufname('%'))
  call assert_equal(0, &diff)
  call feedkeys(":diffput \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput ', @:)
  call feedkeys(":diffget \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget ', @:)
  call assert_equal([], getcompletion('', 'diff_buffer'))

  wincmd j
  call assert_equal('Xdiff4', bufname('%'))
  call feedkeys(":diffput \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput Xdiff1 Xdiff3', @:)
  call feedkeys(":diffget \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget Xdiff1 Xdiff3', @:)
  call assert_equal(['Xdiff1', 'Xdiff3'], getcompletion('', 'diff_buffer'))

  %bwipe
endfunc

func Test_dp_do_buffer()
  e! one
  let bn1=bufnr('%')
  let l = range(60)
  call setline(1, l)
  diffthis

  new two
  let l[10] = 'one'
  let l[20] = 'two'
  let l[30] = 'three'
  let l[40] = 'four'
  let l[50] = 'five'
  call setline(1, l)
  diffthis

  " dp and do with invalid buffer number.
  11
  call assert_fails('norm 99999dp', 'E102:')
  call assert_fails('norm 99999do', 'E102:')
  call assert_fails('diffput non_existing_buffer', 'E94:')
  call assert_fails('diffget non_existing_buffer', 'E94:')

  " dp and do with valid buffer number.
  call assert_equal('one', getline('.'))
  exe 'norm ' . bn1 . 'do'
  call assert_equal('10', getline('.'))
  21
  call assert_equal('two', getline('.'))
  diffget one
  call assert_equal('20', getline('.'))

  31
  exe 'norm ' . bn1 . 'dp'
  41
  diffput one
  wincmd w
  31
  call assert_equal('three', getline('.'))
  41
  call assert_equal('four', getline('.'))

  " dp and do with buffer number which is not in diff mode.
  new not_in_diff_mode
  let bn3=bufnr('%')
  wincmd w
  51
  call assert_fails('exe "norm" . bn3 . "dp"', 'E103:')
  call assert_fails('exe "norm" . bn3 . "do"', 'E103:')
  call assert_fails('diffput not_in_diff_mode', 'E94:')
  call assert_fails('diffget not_in_diff_mode', 'E94:')

  windo diffoff
  %bwipe!
endfunc

func Test_do_lastline()
  e! one
  call setline(1, ['1','2','3','4','5','6'])
  diffthis

  new two
  call setline(1, ['2','4','5'])
  diffthis

  1
  norm dp]c
  norm dp]c
  wincmd w
  call assert_equal(4, line('$'))
  norm G
  norm do
  call assert_equal(3, line('$'))

  windo diffoff
  %bwipe!
endfunc

func Test_diffoff()
  enew!
  call setline(1, ['Two', 'Three'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis
  botright vert new
  call setline(1, ['One', '', 'Two', 'Three'])
  diffthis
  redraw
  call assert_notequal(normattr, 1->screenattr(1))
  diffoff!
  redraw
  call assert_equal(normattr, screenattr(1, 1))
  bwipe!
  bwipe!
endfunc

func Common_icase_test()
  edit one
  call setline(1, ['One', 'Two', 'Three', 'Four', 'Fi#ve'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis

  botright vert new two
  call setline(1, ['one', 'TWO', 'Three ', 'Four', 'fI=VE'])
  diffthis

  redraw
  call assert_equal(normattr, screenattr(1, 1))
  call assert_equal(normattr, screenattr(2, 1))
  call assert_notequal(normattr, screenattr(3, 1))
  call assert_equal(normattr, screenattr(4, 1))

  let dtextattr = screenattr(5, 3)
  call assert_notequal(dtextattr, screenattr(5, 1))
  call assert_notequal(dtextattr, screenattr(5, 5))

  diffoff!
  %bwipe!
endfunc

func Test_diffopt_icase()
  set diffopt=icase,foldcolumn:0
  call Common_icase_test()
  set diffopt&
endfunc

func Test_diffopt_icase_internal()
  set diffopt=icase,foldcolumn:0,internal
  call Common_icase_test()
  set diffopt&
endfunc

func Common_iwhite_test()
  edit one
  " Difference in trailing spaces and amount of spaces should be ignored,
  " but not other space differences.
  call setline(1, ["One \t", 'Two', 'Three', 'one two', 'one two', 'Four'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis

  botright vert new two
  call setline(1, ["One\t ", "Two\t ", 'Three', 'one   two', 'onetwo', ' Four'])
  diffthis

  redraw
  call assert_equal(normattr, screenattr(1, 1))
  call assert_equal(normattr, screenattr(2, 1))
  call assert_equal(normattr, screenattr(3, 1))
  call assert_equal(normattr, screenattr(4, 1))
  call assert_notequal(normattr, screenattr(5, 1))
  call assert_notequal(normattr, screenattr(6, 1))

  diffoff!
  %bwipe!
endfunc

func Test_diffopt_iwhite()
  set diffopt=iwhite,foldcolumn:0
  call Common_iwhite_test()
  set diffopt&
endfunc

func Test_diffopt_iwhite_internal()
  set diffopt=internal,iwhite,foldcolumn:0
  call Common_iwhite_test()
  set diffopt&
endfunc

func Test_diffopt_context()
  enew!
  call setline(1, ['1', '2', '3', '4', '5', '6', '7'])
  diffthis
  new
  call setline(1, ['1', '2', '3', '4', '5x', '6', '7'])
  diffthis

  set diffopt=context:2
  call assert_equal('+--  2 lines: 1', foldtextresult(1))
  set diffopt=internal,context:2
  call assert_equal('+--  2 lines: 1', foldtextresult(1))

  set diffopt=context:1
  call assert_equal('+--  3 lines: 1', foldtextresult(1))
  set diffopt=internal,context:1
  call assert_equal('+--  3 lines: 1', foldtextresult(1))

  diffoff!
  %bwipe!
  set diffopt&
endfunc

func Test_diffopt_horizontal()
  set diffopt=internal,horizontal
  diffsplit

  call assert_equal(&columns, winwidth(1))
  call assert_equal(&columns, winwidth(2))
  call assert_equal(&lines, winheight(1) + winheight(2) + 3)
  call assert_inrange(0, 1, winheight(1) - winheight(2))

  set diffopt&
  diffoff!
  %bwipe
endfunc

func Test_diffopt_vertical()
  set diffopt=internal,vertical
  diffsplit

  call assert_equal(&lines - 2, winheight(1))
  call assert_equal(&lines - 2, winheight(2))
  call assert_equal(&columns, winwidth(1) + winwidth(2) + 1)
  call assert_inrange(0, 1, winwidth(1) - winwidth(2))

  set diffopt&
  diffoff!
  %bwipe
endfunc

func Test_diffopt_hiddenoff()
  set diffopt=internal,filler,foldcolumn:0,hiddenoff
  e! one
  call setline(1, ['Two', 'Three'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis
  botright vert new two
  call setline(1, ['One', 'Four'])
  diffthis
  redraw
  call assert_notequal(normattr, screenattr(1, 1))
  set hidden
  close
  redraw
  " should not diffing with hidden buffer two while 'hiddenoff' is enabled
  call assert_equal(normattr, screenattr(1, 1))

  bwipe!
  bwipe!
  set hidden& diffopt&
endfunc

func Test_diffoff_hidden()
  set diffopt=internal,filler,foldcolumn:0
  e! one
  call setline(1, ['Two', 'Three'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis
  botright vert new two
  call setline(1, ['One', 'Four'])
  diffthis
  redraw
  call assert_notequal(normattr, screenattr(1, 1))
  set hidden
  close
  redraw
  " diffing with hidden buffer two
  call assert_notequal(normattr, screenattr(1, 1))
  diffoff
  redraw
  call assert_equal(normattr, screenattr(1, 1))
  diffthis
  redraw
  " still diffing with hidden buffer two
  call assert_notequal(normattr, screenattr(1, 1))
  diffoff!
  redraw
  call assert_equal(normattr, screenattr(1, 1))
  diffthis
  redraw
  " no longer diffing with hidden buffer two
  call assert_equal(normattr, screenattr(1, 1))

  bwipe!
  bwipe!
  set hidden& diffopt&
endfunc

func Test_setting_cursor()
  new Xtest1
  put =range(1,90)
  wq
  new Xtest2
  put =range(1,100)
  wq

  tabe Xtest2
  $
  diffsp Xtest1
  tabclose

  call delete('Xtest1')
  call delete('Xtest2')
endfunc

func Test_diff_move_to()
  new
  call setline(1, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  diffthis
  vnew
  call setline(1, [1, '2x', 3, 4, 4, 5, '6x', 7, '8x', 9, '10x'])
  diffthis
  norm ]c
  call assert_equal(2, line('.'))
  norm 3]c
  call assert_equal(9, line('.'))
  norm 10]c
  call assert_equal(11, line('.'))
  norm [c
  call assert_equal(9, line('.'))
  norm 2[c
  call assert_equal(5, line('.'))
  norm 10[c
  call assert_equal(2, line('.'))
  %bwipe!
endfunc

func Test_diffexpr()
  CheckExecutable diff

  func DiffExpr()
    " Prepend some text to check diff type detection
    call writefile(['warning', '  message'], v:fname_out)
    silent exe '!diff ' . v:fname_in . ' ' . v:fname_new . '>>' . v:fname_out
  endfunc
  set diffexpr=DiffExpr()
  set diffopt=foldcolumn:0

  enew!
  call setline(1, ['one', 'two', 'three'])
  redraw
  let normattr = screenattr(1, 1)
  diffthis

  botright vert new
  call setline(1, ['one', 'two', 'three.'])
  diffthis

  redraw
  call assert_equal(normattr, screenattr(1, 1))
  call assert_equal(normattr, screenattr(2, 1))
  call assert_notequal(normattr, screenattr(3, 1))
  diffoff!

  " Try using a non-existing function for 'diffexpr'.
  set diffexpr=NewDiffFunc()
  call assert_fails('windo diffthis', ['E117:', 'E97:'])
  diffoff!

  " Using a script-local function
  func s:NewDiffExpr()
  endfunc
  set diffexpr=s:NewDiffExpr()
  call assert_equal(expand('<SID>') .. 'NewDiffExpr()', &diffexpr)
  set diffexpr=<SID>NewDiffExpr()
  call assert_equal(expand('<SID>') .. 'NewDiffExpr()', &diffexpr)

  %bwipe!
  set diffexpr& diffopt&
  delfunc DiffExpr
  delfunc s:NewDiffExpr
endfunc

func Test_diffpatch()
  " The patch program on MS-Windows may fail or hang.
  CheckExecutable patch
  CheckUnix
  new
  insert
***************
*** 1,3 ****
  1
! 2
  3
--- 1,4 ----
  1
! 2x
  3
+ 4
.
  saveas! Xpatch
  bwipe!
  new
  call assert_fails('diffpatch Xpatch', 'E816:')

  for name in ['Xpatch', 'Xpatch$HOME', 'Xpa''tch']
    call setline(1, ['1', '2', '3'])
    if name != 'Xpatch'
      call rename('Xpatch', name)
    endif
    exe 'diffpatch ' . escape(name, '$')
    call assert_equal(['1', '2x', '3', '4'], getline(1, '$'))
    if name != 'Xpatch'
      call rename(name, 'Xpatch')
    endif
    bwipe!
  endfor

  call delete('Xpatch')
  bwipe!
endfunc

" FIXME: test fails, the Xresult file can't be read
func No_Test_diffpatch_restricted()
  let lines =<< trim END
    call assert_fails('diffpatch NoSuchDiff', 'E145:')

    call writefile(v:errors, 'Xresult')
    qa!
  END
  call writefile(lines, 'Xrestricted', 'D')
  if RunVim([], [], '-Z --clean -S Xrestricted')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

func Test_diff_too_many_buffers()
  for i in range(1, 8)
    exe "new Xtest" . i
    diffthis
  endfor
  new Xtest9
  call assert_fails('diffthis', 'E96:')
  %bwipe!
endfunc

func Test_diff_nomodifiable()
  new
  call setline(1, [1, 2, 3, 4])
  setl nomodifiable
  diffthis
  vnew
  call setline(1, ['1x', 2, 3, 3, 4])
  diffthis
  call assert_fails('norm dp', 'E793:')
  setl nomodifiable
  call assert_fails('norm do', 'E21:')
  %bwipe!
endfunc

func Test_diff_hlID()
  new
  call setline(1, [1, 2, 3])
  diffthis
  vnew
  call setline(1, ['1x', 2, 'x', 3])
  diffthis
  redraw

  call diff_hlID(-1, 1)->synIDattr("name")->assert_equal("")

  call diff_hlID(1, 1)->synIDattr("name")->assert_equal("DiffChange")
  call diff_hlID(1, 2)->synIDattr("name")->assert_equal("DiffText")
  call diff_hlID(2, 1)->synIDattr("name")->assert_equal("")
  call diff_hlID(3, 1)->synIDattr("name")->assert_equal("DiffAdd")
  eval 4->diff_hlID(1)->synIDattr("name")->assert_equal("")

  wincmd w
  call assert_equal(synIDattr(diff_hlID(1, 1), "name"), "DiffChange")
  call assert_equal(synIDattr(diff_hlID(2, 1), "name"), "")
  call assert_equal(synIDattr(diff_hlID(3, 1), "name"), "")

  %bwipe!
endfunc

func Test_diff_filler()
  new
  call setline(1, [1, 2, 3, 'x', 4])
  diffthis
  vnew
  call setline(1, [1, 2, 'y', 'y', 3, 4])
  diffthis
  redraw

  call assert_equal([0, 0, 0, 0, 0, 0, 0, 1, 0], map(range(-1, 7), 'v:val->diff_filler()'))
  wincmd w
  call assert_equal([0, 0, 0, 0, 2, 0, 0, 0], map(range(-1, 6), 'diff_filler(v:val)'))

  %bwipe!
endfunc

func Test_diff_lastline()
  enew!
  only!
  call setline(1, ['This is a ', 'line with five ', 'rows'])
  diffthis
  botright vert new
  call setline(1, ['This is', 'a line with ', 'four rows'])
  diffthis
  1
  call feedkeys("Je a\<CR>", 'tx')
  call feedkeys("Je a\<CR>", 'tx')
  let w1lines = winline()
  wincmd w
  $
  let w2lines = winline()
  call assert_equal(w2lines, w1lines)
  bwipe!
  bwipe!
endfunc

func WriteDiffFiles(buf, list1, list2)
  call writefile(a:list1, 'Xdifile1')
  call writefile(a:list2, 'Xdifile2')
  if a:buf
    call term_sendkeys(a:buf, ":checktime\<CR>")
  endif
endfunc

" Verify a screendump with both the internal and external diff.
func VerifyBoth(buf, dumpfile, extra)
  " trailing : for leaving the cursor on the command line
  for cmd in [":set diffopt=filler" . a:extra . "\<CR>:", ":set diffopt+=internal\<CR>:"]
    call term_sendkeys(a:buf, cmd)
    if VerifyScreenDump(a:buf, a:dumpfile, {}, cmd =~ 'internal' ? 'internal' : 'external')
      " don't let the next iteration overwrite the "failed" file.
      return
    endif
  endfor

  " also test unified diff
  call term_sendkeys(a:buf, ":call SetupUnified()\<CR>:")
  call term_sendkeys(a:buf, ":redraw!\<CR>:")
  call VerifyScreenDump(a:buf, a:dumpfile, {}, 'unified')
  call term_sendkeys(a:buf, ":call StopUnified()\<CR>:")
endfunc

" Verify a screendump with the internal diff only.
func VerifyInternal(buf, dumpfile, extra)
  call term_sendkeys(a:buf, ":diffupdate!\<CR>")
  " trailing : for leaving the cursor on the command line
  call term_sendkeys(a:buf, ":set diffopt=internal,filler" . a:extra . "\<CR>:")
  call VerifyScreenDump(a:buf, a:dumpfile, {})
endfunc

func Test_diff_screen()
  if has('osx') && !empty($CI) && system('uname -m') =~# 'arm64'
    throw 'Skipped: FIXME: This test fails on M1 Mac on GitHub Actions'
  endif

  let g:test_is_flaky = 1
  CheckScreendump
  CheckFeature menu

  let lines =<< trim END
      func UnifiedDiffExpr()
        " Prepend some text to check diff type detection
        call writefile(['warning', '  message'], v:fname_out)
        silent exe '!diff -U0 ' .. v:fname_in .. ' ' .. v:fname_new .. '>>' .. v:fname_out
      endfunc
      func SetupUnified()
        set diffexpr=UnifiedDiffExpr()
        diffupdate
      endfunc
      func StopUnified()
        set diffexpr=
      endfunc
  END
  call writefile(lines, 'XdiffSetup', 'D')

  " clean up already existing swap files, just in case
  call delete('.Xdifile1.swp')
  call delete('.Xdifile2.swp')

  " Test 1: Add a line in beginning of file 2
  call WriteDiffFiles(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  let buf = RunVimInTerminal('-d -S XdiffSetup Xdifile1 Xdifile2', {})
  " Set autoread mode, so that Vim won't complain once we re-write the test
  " files
  call term_sendkeys(buf, ":set autoread\<CR>\<c-w>w:set autoread\<CR>\<c-w>w")

  call VerifyBoth(buf, 'Test_diff_01', '')

  " Test 2: Add a line in beginning of file 1
  call WriteDiffFiles(buf, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  call VerifyBoth(buf, 'Test_diff_02', '')

  " Test 3: Add a line at the end of file 2
  call WriteDiffFiles(buf, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  call VerifyBoth(buf, 'Test_diff_03', '')

  " Test 4: Add a line at the end of file 1
  call WriteDiffFiles(buf, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  call VerifyBoth(buf, 'Test_diff_04', '')

  " Test 5: Add a line in the middle of file 2, remove on at the end of file 1
  call WriteDiffFiles(buf, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10])
  call VerifyBoth(buf, 'Test_diff_05', '')

  " Test 6: Add a line in the middle of file 1, remove on at the end of file 2
  call WriteDiffFiles(buf, [1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  call VerifyBoth(buf, 'Test_diff_06', '')

  " Variants on test 6 with different context settings
  call term_sendkeys(buf, ":set diffopt+=context:2\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_06.2', {})
  call term_sendkeys(buf, ":set diffopt-=context:2\<cr>")
  call term_sendkeys(buf, ":set diffopt+=context:1\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_06.1', {})
  call term_sendkeys(buf, ":set diffopt-=context:1\<cr>")
  call term_sendkeys(buf, ":set diffopt+=context:0\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_06.0', {})
  call term_sendkeys(buf, ":set diffopt-=context:0\<cr>")

  " Test 7 - 9: Test normal/patience/histogram diff algorithm
  call WriteDiffFiles(buf, ['#include <stdio.h>', '', '// Frobs foo heartily', 'int frobnitz(int foo)', '{',
      \ '    int i;', '    for(i = 0; i < 10; i++)', '    {', '        printf("Your answer is: ");',
      \ '        printf("%d\n", foo);', '    }', '}', '', 'int fact(int n)', '{', '    if(n > 1)', '    {',
      \ '        return fact(n-1) * n;', '    }', '    return 1;', '}', '', 'int main(int argc, char **argv)',
      \ '{', '    frobnitz(fact(10));', '}'],
      \ ['#include <stdio.h>', '', 'int fib(int n)', '{', '    if(n > 2)', '    {',
      \ '        return fib(n-1) + fib(n-2);', '    }', '    return 1;', '}', '', '// Frobs foo heartily',
      \ 'int frobnitz(int foo)', '{', '    int i;', '    for(i = 0; i < 10; i++)', '    {',
      \ '        printf("%d\n", foo);', '    }', '}', '',
      \ 'int main(int argc, char **argv)', '{', '    frobnitz(fib(10));', '}'])
  call term_sendkeys(buf, ":diffupdate!\<cr>")
  call term_sendkeys(buf, ":set diffopt+=internal\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_07', {})

  call term_sendkeys(buf, ":set diffopt+=algorithm:patience\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_08', {})

  call term_sendkeys(buf, ":set diffopt+=algorithm:histogram\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_09', {})

  " Test 10-11: normal/indent-heuristic
  call term_sendkeys(buf, ":set diffopt&vim\<cr>")
  call WriteDiffFiles(buf, ['', '  def finalize(values)', '', '    values.each do |v|', '      v.finalize', '    end'],
      \ ['', '  def finalize(values)', '', '    values.each do |v|', '      v.prepare', '    end', '',
      \ '    values.each do |v|', '      v.finalize', '    end'])
  call term_sendkeys(buf, ":diffupdate!\<cr>")
  call term_sendkeys(buf, ":set diffopt+=internal\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_10', {})

  " Leave trailing : at commandline!
  call term_sendkeys(buf, ":set diffopt+=indent-heuristic\<cr>:\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_11', {}, 'one')
  " shouldn't matter, if indent-algorithm comes before or after the algorithm
  call term_sendkeys(buf, ":set diffopt&\<cr>")
  call term_sendkeys(buf, ":set diffopt+=indent-heuristic,algorithm:patience\<cr>:\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_11', {}, 'two')
  call term_sendkeys(buf, ":set diffopt&\<cr>")
  call term_sendkeys(buf, ":set diffopt+=algorithm:patience,indent-heuristic\<cr>:\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_11', {}, 'three')

  " Test 12: diff the same file
  call WriteDiffFiles(buf, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  call VerifyBoth(buf, 'Test_diff_12', '')

  " Test 13: diff an empty file
  call WriteDiffFiles(buf, [], [])
  call VerifyBoth(buf, 'Test_diff_13', '')

  " Test 14: test diffopt+=icase
  call WriteDiffFiles(buf, ['a', 'b', 'cd'], ['A', 'b', 'cDe'])
  call VerifyBoth(buf, 'Test_diff_14', " diffopt+=filler diffopt+=icase")

  " Test 15-16: test diffopt+=iwhite
  call WriteDiffFiles(buf, ['int main()', '{', '   printf("Hello, World!");', '   return 0;', '}'],
      \ ['int main()', '{', '   if (0)', '   {', '      printf("Hello, World!");', '      return 0;', '   }', '}'])
  call term_sendkeys(buf, ":diffupdate!\<cr>")
  call term_sendkeys(buf, ":set diffopt&vim diffopt+=filler diffopt+=iwhite\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_15', {})
  call term_sendkeys(buf, ":set diffopt+=internal\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_16', {})

  " Test 17: test diffopt+=iblank
  call WriteDiffFiles(buf, ['a', ' ', 'cd', 'ef', 'xxx'], ['a', 'cd', '', 'ef', 'yyy'])
  call VerifyInternal(buf, 'Test_diff_17', " diffopt+=iblank")

  " Test 18: test diffopt+=iblank,iwhite / iwhiteall / iwhiteeol
  call VerifyInternal(buf, 'Test_diff_18', " diffopt+=iblank,iwhite")
  call VerifyInternal(buf, 'Test_diff_18', " diffopt+=iblank,iwhiteall")
  call VerifyInternal(buf, 'Test_diff_18', " diffopt+=iblank,iwhiteeol")

  " Test 19: test diffopt+=iwhiteeol
  call WriteDiffFiles(buf, ['a ', 'x', 'cd', 'ef', 'xx  xx', 'foo', 'bar'], ['a', 'x', 'c d', ' ef', 'xx xx', 'foo', '', 'bar'])
  call VerifyInternal(buf, 'Test_diff_19', " diffopt+=iwhiteeol")

  " Test 19: test diffopt+=iwhiteall
  call VerifyInternal(buf, 'Test_diff_20', " diffopt+=iwhiteall")

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xdifile1')
  call delete('Xdifile2')
endfunc

func Test_diff_with_scroll_and_change()
  CheckScreendump

  let lines =<< trim END
	call setline(1, range(1, 15))
	vnew
	call setline(1, range(9, 15))
	windo diffthis
	wincmd h
	exe "normal Gl5\<C-E>"
  END
  call writefile(lines, 'Xtest_scroll_change', 'D')
  let buf = RunVimInTerminal('-S Xtest_scroll_change', {})

  call VerifyScreenDump(buf, 'Test_diff_scroll_change_01', {})

  call term_sendkeys(buf, "ax\<Esc>")
  call VerifyScreenDump(buf, 'Test_diff_scroll_change_02', {})

  call term_sendkeys(buf, "\<C-W>lay\<Esc>")
  call VerifyScreenDump(buf, 'Test_diff_scroll_change_03', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_with_cursorline()
  CheckScreendump

  call writefile([
	\ 'hi CursorLine ctermbg=red ctermfg=white',
	\ 'set cursorline',
	\ 'call setline(1, ["foo","foo","foo","bar"])',
	\ 'vnew',
	\ 'call setline(1, ["bee","foo","foo","baz"])',
	\ 'windo diffthis',
	\ '2wincmd w',
	\ ], 'Xtest_diff_cursorline', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_cursorline', {})

  call VerifyScreenDump(buf, 'Test_diff_with_cursorline_01', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_with_cursorline_02', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_with_cursorline_03', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_with_cursorline_number()
  CheckScreendump

  let lines =<< trim END
      hi CursorLine ctermbg=red ctermfg=white
      hi CursorLineNr ctermbg=white ctermfg=black cterm=underline
      set cursorline number
      call setline(1, ["baz", "foo", "foo", "bar"])
      2
      vnew
      call setline(1, ["foo", "foo", "bar"])
      windo diffthis
      1wincmd w
  END
  call writefile(lines, 'Xtest_diff_cursorline_number', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_cursorline_number', {})

  call VerifyScreenDump(buf, 'Test_diff_with_cursorline_number_01', {})
  call term_sendkeys(buf, ":set cursorlineopt=number\r")
  call VerifyScreenDump(buf, 'Test_diff_with_cursorline_number_02', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_with_cursorline_breakindent()
  CheckScreendump

  let lines =<< trim END
    hi CursorLine ctermbg=red ctermfg=white
    set noequalalways wrap diffopt=followwrap cursorline breakindent
    50vnew
    call setline(1, ['  ', '  ', '  ', '  '])
    exe "norm! 20Afoo\<Esc>j20Afoo\<Esc>j20Afoo\<Esc>j20Abar\<Esc>"
    vnew
    call setline(1, ['  ', '  ', '  ', '  '])
    exe "norm! 20Abee\<Esc>j20Afoo\<Esc>j20Afoo\<Esc>j20Abaz\<Esc>"
    windo diffthis
    2wincmd w
  END
  call writefile(lines, 'Xtest_diff_cursorline_breakindent', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_cursorline_breakindent', {})

  call term_sendkeys(buf, "gg0")
  call VerifyScreenDump(buf, 'Test_diff_with_cul_bri_01', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_with_cul_bri_02', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_with_cul_bri_03', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_with_cul_bri_04', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_breakindent_after_filler()
  CheckScreendump

  let lines =<< trim END
    set laststatus=0 diffopt+=followwrap breakindent
    call setline(1, ['a', '  ' .. repeat('c', 50)])
    vnew
    call setline(1, ['a', 'b', '  ' .. repeat('c', 50)])
    windo diffthis
    norm! G$
  END
  call writefile(lines, 'Xtest_diff_breakindent_after_filler', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_breakindent_after_filler', #{rows: 8, cols: 45})
  call VerifyScreenDump(buf, 'Test_diff_breakindent_after_filler', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_with_syntax()
  CheckScreendump

  let lines =<< trim END
	void doNothing() {
	   int x = 0;
	   char *s = "hello";
	   return 5;
	}
  END
  call writefile(lines, 'Xprogram1.c', 'D')
  let lines =<< trim END
	void doSomething() {
	   int x = 0;
	   char *s = "there";
	   return 5;
	}
  END
  call writefile(lines, 'Xprogram2.c', 'D')

  let lines =<< trim END
	edit Xprogram1.c
	diffsplit Xprogram2.c
  END
  call writefile(lines, 'Xtest_diff_syntax', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_syntax', {})

  call VerifyScreenDump(buf, 'Test_diff_syntax_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_of_diff()
  CheckScreendump
  CheckFeature rightleft

  call writefile([
	\ 'call setline(1, ["aa","bb","cc","@@ -3,2 +5,7 @@","dd","ee","ff"])',
	\ 'vnew',
	\ 'call setline(1, ["aa","bb","cc"])',
	\ 'windo diffthis',
	\ '1wincmd w',
	\ 'setlocal number',
	\ ], 'Xtest_diff_diff', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_diff', {})

  call VerifyScreenDump(buf, 'Test_diff_of_diff_01', {})

  call term_sendkeys(buf, ":set rightleft\<cr>")
  call VerifyScreenDump(buf, 'Test_diff_of_diff_02', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func CloseoffSetup()
  enew
  call setline(1, ['one', 'two', 'three'])
  diffthis
  new
  call setline(1, ['one', 'tow', 'three'])
  diffthis
  call assert_equal(1, &diff)
  only!
endfunc

func Test_diff_closeoff()
  " "closeoff" included by default: last diff win gets 'diff' reset'
  call CloseoffSetup()
  call assert_equal(0, &diff)
  enew!

  " "closeoff" excluded: last diff win keeps 'diff' set'
  set diffopt-=closeoff
  call CloseoffSetup()
  call assert_equal(1, &diff)
  diffoff!
  enew!
endfunc

func Test_diff_followwrap()
  new
  set diffopt+=followwrap
  set wrap
  diffthis
  call assert_equal(1, &wrap)
  diffoff
  set nowrap
  diffthis
  call assert_equal(0, &wrap)
  diffoff
  set diffopt&
  bwipe!
endfunc

func Test_diff_maintains_change_mark()
  func DiffMaintainsChangeMark()
    enew!
    call setline(1, ['a', 'b', 'c', 'd'])
    diffthis
    new
    call setline(1, ['a', 'b', 'c', 'e'])
    " Set '[ and '] marks
    2,3yank
    call assert_equal([2, 3], [line("'["), line("']")])
    " Verify they aren't affected by the implicit diff
    diffthis
    call assert_equal([2, 3], [line("'["), line("']")])
    " Verify they aren't affected by an explicit diff
    diffupdate
    call assert_equal([2, 3], [line("'["), line("']")])
    bwipe!
    bwipe!
  endfunc

  set diffopt-=internal
  call DiffMaintainsChangeMark()
  set diffopt+=internal
  call DiffMaintainsChangeMark()

  set diffopt&
  delfunc DiffMaintainsChangeMark
endfunc

" Test for 'patchexpr'
func Test_patchexpr()
  let g:patch_args = []
  func TPatch()
    call add(g:patch_args, readfile(v:fname_in))
    call add(g:patch_args, readfile(v:fname_diff))
    call writefile(['output file'], v:fname_out)
  endfunc
  set patchexpr=TPatch()

  call writefile(['input file'], 'Xinput', 'D')
  call writefile(['diff file'], 'Xdiff', 'D')
  %bwipe!
  edit Xinput
  diffpatch Xdiff
  call assert_equal('output file', getline(1))
  call assert_equal('Xinput.new', bufname())
  call assert_equal(2, winnr('$'))
  call assert_true(&diff)

  " Using a script-local function
  func s:NewPatchExpr()
  endfunc
  set patchexpr=s:NewPatchExpr()
  call assert_equal(expand('<SID>') .. 'NewPatchExpr()', &patchexpr)
  set patchexpr=<SID>NewPatchExpr()
  call assert_equal(expand('<SID>') .. 'NewPatchExpr()', &patchexpr)

  set patchexpr&
  delfunc TPatch
  delfunc s:NewPatchExpr
  %bwipe!
endfunc

func Test_diff_rnu()
  CheckScreendump

  let content =<< trim END
    call setline(1, ['a', 'a', 'a', 'y', 'b', 'b', 'b', 'b', 'b'])
    vnew
    call setline(1, ['a', 'a', 'a', 'x', 'x', 'x', 'b', 'b', 'b', 'b', 'b'])
    windo diffthis
    setlocal number rnu foldcolumn=0
  END
  call writefile(content, 'Xtest_diff_rnu', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_rnu', {})

  call VerifyScreenDump(buf, 'Test_diff_rnu_01', {})

  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_rnu_02', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_rnu_03', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_diff_multilineconceal()
  new
  diffthis

  new
  call matchadd('Conceal', 'a\nb', 9, -1, {'conceal': 'Y'})
  set cole=2 cocu=n
  call setline(1, ["a", "b"])
  diffthis
  redraw
endfunc

func Test_diff_and_scroll()
  " this was causing an ml_get error
  set ls=2
  for i in range(winheight(0) * 2)
    call setline(i, i < winheight(0) - 10 ? i : i + 10)
  endfor
  vnew
  for i in range(winheight(0)*2 + 10)
    call setline(i, i < winheight(0) - 10 ? 0 : i)
  endfor
  diffthis
  wincmd p
  diffthis
  execute 'normal ' . winheight(0) . "\<C-d>"

  bwipe!
  bwipe!
  set ls&
endfunc

func Test_diff_filler_cursorcolumn()
  CheckScreendump

  let content =<< trim END
    call setline(1, ['aa', 'bb', 'cc'])
    vnew
    call setline(1, ['aa', 'cc'])
    windo diffthis
    wincmd p
    setlocal cursorcolumn foldcolumn=0
    norm! gg0
    redraw!
  END
  call writefile(content, 'Xtest_diff_cuc', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_cuc', {})

  call VerifyScreenDump(buf, 'Test_diff_cuc_01', {})

  call term_sendkeys(buf, "l")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_cuc_02', {})
  call term_sendkeys(buf, "0j")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_cuc_03', {})
  call term_sendkeys(buf, "l")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_cuc_04', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

" Test for adding/removing lines inside diff chunks, between diff chunks
" and before diff chunks
func Test_diff_modify_chunks()
  enew!
  let w2_id = win_getid()
  call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
  new
  let w1_id = win_getid()
  call setline(1, ['a', '2', '3', 'd', 'e', 'f', '7', '8', 'i'])
  windo diffthis

  " remove a line between two diff chunks and create a new diff chunk
  call win_gotoid(w2_id)
  5d
  call win_gotoid(w1_id)
  call diff_hlID(5, 1)->synIDattr('name')->assert_equal('DiffAdd')

  " add a line between two diff chunks
  call win_gotoid(w2_id)
  normal! 4Goe
  call win_gotoid(w1_id)
  call diff_hlID(4, 1)->synIDattr('name')->assert_equal('')
  call diff_hlID(5, 1)->synIDattr('name')->assert_equal('')

  " remove all the lines in a diff chunk.
  call win_gotoid(w2_id)
  7,8d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', 'DiffText', 'DiffText', '', '', '', 'DiffAdd',
        \ 'DiffAdd', ''], hl)

  " remove lines from one diff chunk to just before the next diff chunk
  call win_gotoid(w2_id)
  call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
  2,6d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', 'DiffText', 'DiffText', 'DiffAdd', 'DiffAdd',
        \ 'DiffAdd', 'DiffAdd', 'DiffAdd', ''], hl)

  " remove lines just before the top of a diff chunk
  call win_gotoid(w2_id)
  call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
  5,6d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', 'DiffText', 'DiffText', '', 'DiffText', 'DiffText',
        \ 'DiffAdd', 'DiffAdd', ''], hl)

  " remove line after the end of a diff chunk
  call win_gotoid(w2_id)
  call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
  4d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', 'DiffText', 'DiffText', 'DiffAdd', '', '', 'DiffText',
        \ 'DiffText', ''], hl)

  " remove lines starting from the end of one diff chunk and ending inside
  " another diff chunk
  call win_gotoid(w2_id)
  call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
  4,7d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', 'DiffText', 'DiffText', 'DiffText', 'DiffAdd',
        \ 'DiffAdd', 'DiffAdd', 'DiffAdd', ''], hl)

  " removing the only remaining diff chunk should make the files equal
  call win_gotoid(w2_id)
  call setline(1, ['a', '2', '3', 'x', 'd', 'e', 'f', 'x', '7', '8', 'i'])
  8d
  let hl = range(1, 10)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', '', '', 'DiffAdd', '', '', '', '', '', ''], hl)
  call win_gotoid(w2_id)
  4d
  call win_gotoid(w1_id)
  let hl = range(1, 9)->map({_, lnum -> diff_hlID(lnum, 1)->synIDattr('name')})
  call assert_equal(['', '', '', '', '', '', '', '', ''], hl)

  %bw!
endfunc

func Test_diff_binary()
  CheckScreendump

  let content =<< trim END
    call setline(1, ['a', 'b', "c\n", 'd', 'e', 'f', 'g'])
    vnew
    call setline(1, ['A', 'b', 'c', 'd', 'E', 'f', 'g'])
    windo diffthis
    wincmd p
    norm! gg0
    redraw!
  END
  call writefile(content, 'Xtest_diff_bin', 'D')
  let buf = RunVimInTerminal('-S Xtest_diff_bin', {})

  " Test using internal diff
  call VerifyScreenDump(buf, 'Test_diff_bin_01', {})

  " Test using internal diff and case folding
  call term_sendkeys(buf, ":set diffopt+=icase\<cr>")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_bin_02', {})
  " Test using external diff
  call term_sendkeys(buf, ":set diffopt=filler\<cr>")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_bin_03', {})
  " Test using external diff and case folding
  call term_sendkeys(buf, ":set diffopt=filler,icase\<cr>")
  call term_sendkeys(buf, "\<C-l>")
  call VerifyScreenDump(buf, 'Test_diff_bin_04', {})

  " clean up
  call StopVimInTerminal(buf)
  set diffopt&vim
endfunc

" Test for using the 'zi' command to invert 'foldenable' in diff windows (test
" for the issue fixed by patch 6.2.317)
func Test_diff_foldinvert()
  %bw!
  edit Xdoffile1
  new Xdoffile2
  new Xdoffile3
  windo diffthis
  " open a non-diff window
  botright new
  1wincmd w
  call assert_true(getwinvar(1, '&foldenable'))
  call assert_true(getwinvar(2, '&foldenable'))
  call assert_true(getwinvar(3, '&foldenable'))
  normal zi
  call assert_false(getwinvar(1, '&foldenable'))
  call assert_false(getwinvar(2, '&foldenable'))
  call assert_false(getwinvar(3, '&foldenable'))
  normal zi
  call assert_true(getwinvar(1, '&foldenable'))
  call assert_true(getwinvar(2, '&foldenable'))
  call assert_true(getwinvar(3, '&foldenable'))

  " If the current window has 'noscrollbind', then 'zi' should not change
  " 'foldenable' in other windows.
  1wincmd w
  set noscrollbind
  normal zi
  call assert_false(getwinvar(1, '&foldenable'))
  call assert_true(getwinvar(2, '&foldenable'))
  call assert_true(getwinvar(3, '&foldenable'))

  " 'zi' should not change the 'foldenable' for windows with 'noscrollbind'
  1wincmd w
  set scrollbind
  normal zi
  call setwinvar(2, '&scrollbind', v:false)
  normal zi
  call assert_false(getwinvar(1, '&foldenable'))
  call assert_true(getwinvar(2, '&foldenable'))
  call assert_false(getwinvar(3, '&foldenable'))

  %bw!
  set scrollbind&
endfunc

" This was scrolling for 'cursorbind' but 'scrollbind' is more important
func Test_diff_scroll()
  CheckScreendump

  let left =<< trim END
      line 1
      line 2
      line 3
      line 4

      // Common block
      // one
      // containing
      // four lines

      // Common block
      // two
      // containing
      // four lines
  END
  call writefile(left, 'Xleft', 'D')
  let right =<< trim END
      line 1
      line 2
      line 3
      line 4

      Lorem
      ipsum
      dolor
      sit
      amet,
      consectetur
      adipiscing
      elit.
      Etiam
      luctus
      lectus
      sodales,
      dictum

      // Common block
      // one
      // containing
      // four lines

      Vestibulum
      tincidunt
      aliquet
      nulla.

      // Common block
      // two
      // containing
      // four lines
  END
  call writefile(right, 'Xright', 'D')
  let buf = RunVimInTerminal('-d Xleft Xright', {'rows': 12})
  call term_sendkeys(buf, "\<C-W>\<C-W>jjjj")
  call VerifyScreenDump(buf, 'Test_diff_scroll_1', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_diff_scroll_2', {})

  call StopVimInTerminal(buf)
endfunc

" This was scrolling too many lines.
func Test_diff_scroll_wrap_on()
  20new
  40vsplit
  call setline(1, map(range(1, 9), 'repeat(v:val, 200)'))
  setlocal number diff so=0
  redraw
  normal! jj
  call assert_equal(1, winsaveview().topline)
  normal! j
  call assert_equal(2, winsaveview().topline)

  bwipe!
  bwipe!
endfunc

func Test_diff_scroll_many_filler()
  20new
  vnew
  call setline(1, ['^^^', '^^^', '$$$', '$$$'])
  diffthis
  setlocal scrolloff=0
  wincmd p
  call setline(1, ['^^^', '^^^'] + repeat(['###'], 41) + ['$$$', '$$$'])
  diffthis
  setlocal scrolloff=0
  wincmd p
  redraw

  " Note: need a redraw after each scroll, otherwise the test always passes.
  normal! G
  redraw
  call assert_equal(3, winsaveview().topline)
  call assert_equal(18, winsaveview().topfill)
  exe "normal! \<C-B>"
  redraw
  call assert_equal(3, winsaveview().topline)
  call assert_equal(19, winsaveview().topfill)
  exe "normal! \<C-B>"
  redraw
  call assert_equal(2, winsaveview().topline)
  call assert_equal(0, winsaveview().topfill)
  exe "normal! \<C-B>"
  redraw
  call assert_equal(1, winsaveview().topline)
  call assert_equal(0, winsaveview().topfill)

  bwipe!
  bwipe!
endfunc

" This was trying to update diffs for a buffer being closed
func Test_diff_only()
  silent! lfile
  set diff
  lopen
  norm o
  silent! norm o

  set nodiff
  %bwipe!
endfunc

" This was causing invalid diff block values
" FIXME: somehow this causes a valgrind error when run directly but not when
" run as a test.
func Test_diff_manipulations()
  set diff
  split 0
  sil! norm RdoobdeuRdoobdeuRdoobdeu

  set nodiff
  %bwipe!
endfunc

" This was causing the line number in the diff block to go below one.
" FIXME: somehow this causes a valgrind error when run directly but not when
" run as a test.
func Test_diff_put_and_undo()
  set diff
  next 0
  split 00
  sil! norm o0gguudpo0ggJuudp

  bwipe!
  bwipe!
  set nodiff
endfunc

" Test for the diff() function
def Test_diff_func()
  # string is added/removed/modified at the beginning
  assert_equal("@@ -0,0 +1 @@\n+abc\n",
               diff(['def'], ['abc', 'def'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 0, to_idx: 0, to_count: 1}],
               diff(['def'], ['abc', 'def'], {output: 'indices'}))
  assert_equal("@@ -1 +0,0 @@\n-abc\n",
               diff(['abc', 'def'], ['def'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 0}],
               diff(['abc', 'def'], ['def'], {output: 'indices'}))
  assert_equal("@@ -1 +1 @@\n-abc\n+abx\n",
               diff(['abc', 'def'], ['abx', 'def'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abc', 'def'], ['abx', 'def'], {output: 'indices'}))

  # string is added/removed/modified at the end
  assert_equal("@@ -1,0 +2 @@\n+def\n",
               diff(['abc'], ['abc', 'def'], {output: 'unified'}))
  assert_equal([{from_idx: 1, from_count: 0, to_idx: 1, to_count: 1}],
               diff(['abc'], ['abc', 'def'], {output: 'indices'}))
  assert_equal("@@ -2 +1,0 @@\n-def\n",
               diff(['abc', 'def'], ['abc'], {output: 'unified'}))
  assert_equal([{from_idx: 1, from_count: 1, to_idx: 1, to_count: 0}],
               diff(['abc', 'def'], ['abc'], {output: 'indices'}))
  assert_equal("@@ -2 +2 @@\n-def\n+xef\n",
               diff(['abc', 'def'], ['abc', 'xef'], {output: 'unified'}))
  assert_equal([{from_idx: 1, from_count: 1, to_idx: 1, to_count: 1}],
               diff(['abc', 'def'], ['abc', 'xef'], {output: 'indices'}))

  # string is added/removed/modified in the middle
  assert_equal("@@ -2,0 +3 @@\n+xxx\n",
               diff(['111', '222', '333'], ['111', '222', 'xxx', '333'], {output: 'unified'}))
  assert_equal([{from_idx: 2, from_count: 0, to_idx: 2, to_count: 1}],
               diff(['111', '222', '333'], ['111', '222', 'xxx', '333'], {output: 'indices'}))
  assert_equal("@@ -3 +2,0 @@\n-333\n",
               diff(['111', '222', '333', '444'], ['111', '222', '444'], {output: 'unified'}))
  assert_equal([{from_idx: 2, from_count: 1, to_idx: 2, to_count: 0}],
               diff(['111', '222', '333', '444'], ['111', '222', '444'], {output: 'indices'}))
  assert_equal("@@ -3 +3 @@\n-333\n+xxx\n",
               diff(['111', '222', '333', '444'], ['111', '222', 'xxx', '444'], {output: 'unified'}))
  assert_equal([{from_idx: 2, from_count: 1, to_idx: 2, to_count: 1}],
               diff(['111', '222', '333', '444'], ['111', '222', 'xxx', '444'], {output: 'indices'}))

  # new strings are added to an empty List
  assert_equal("@@ -0,0 +1,2 @@\n+abc\n+def\n",
               diff([], ['abc', 'def'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 0, to_idx: 0, to_count: 2}],
               diff([], ['abc', 'def'], {output: 'indices'}))

  # all the strings are removed from a List
  assert_equal("@@ -1,2 +0,0 @@\n-abc\n-def\n",
               diff(['abc', 'def'], [], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 2, to_idx: 0, to_count: 0}],
               diff(['abc', 'def'], [], {output: 'indices'}))

  # First character is added/removed/different
  assert_equal("@@ -1 +1 @@\n-abc\n+bc\n",
               diff(['abc'], ['bc'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abc'], ['bc'], {output: 'indices'}))
  assert_equal("@@ -1 +1 @@\n-bc\n+abc\n",
               diff(['bc'], ['abc'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['bc'], ['abc'], {output: 'indices'}))
  assert_equal("@@ -1 +1 @@\n-abc\n+xbc\n",
               diff(['abc'], ['xbc'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abc'], ['xbc'], {output: 'indices'}))

  # Last character is added/removed/different
  assert_equal("@@ -1 +1 @@\n-abc\n+abcd\n",
               diff(['abc'], ['abcd'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abc'], ['abcd'], {output: 'indices'}))
  assert_equal("@@ -1 +1 @@\n-abcd\n+abc\n",
               diff(['abcd'], ['abc'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abcd'], ['abc'], {output: 'indices'}))
  assert_equal("@@ -1 +1 @@\n-abc\n+abx\n",
               diff(['abc'], ['abx'], {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
               diff(['abc'], ['abx'], {output: 'indices'}))

  # partial string modification at the start and at the end.
  var fromlist =<< trim END
    one two
    three four
    five six
  END
  var tolist =<< trim END
    one
    six
  END
  assert_equal("@@ -1,3 +1,2 @@\n-one two\n-three four\n-five six\n+one\n+six\n", diff(fromlist, tolist, {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 3, to_idx: 0, to_count: 2}],
               diff(fromlist, tolist, {output: 'indices'}))

  # non-contiguous modifications
  fromlist =<< trim END
    one two
    three four
    five abc six
  END
  tolist =<< trim END
    one abc two
    three four
    five six
  END
  assert_equal("@@ -1 +1 @@\n-one two\n+one abc two\n@@ -3 +3 @@\n-five abc six\n+five six\n",
               diff(fromlist, tolist, {output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1},
                {from_idx: 2, from_count: 1, to_idx: 2, to_count: 1}],
               diff(fromlist, tolist, {output: 'indices'}))

  # add/remove blank lines
  assert_equal("@@ -2,2 +1,0 @@\n-\n-\n",
               diff(['one', '', '', 'two'], ['one', 'two'], {output: 'unified'}))
  assert_equal([{from_idx: 1, from_count: 2, to_idx: 1, to_count: 0}],
               diff(['one', '', '', 'two'], ['one', 'two'], {output: 'indices'}))
  assert_equal("@@ -1,0 +2,2 @@\n+\n+\n",
               diff(['one', 'two'], ['one', '', '', 'two'], {output: 'unified'}))
  assert_equal([{'from_idx': 1, 'from_count': 0, 'to_idx': 1, 'to_count': 2}],
               diff(['one', 'two'], ['one', '', '', 'two'], {output: 'indices'}))

  # diff ignoring case
  assert_equal('', diff(['abc', 'def'], ['ABC', 'DEF'], {icase: true, output: 'unified'}))
  assert_equal([], diff(['abc', 'def'], ['ABC', 'DEF'], {icase: true, output: 'indices'}))

  # diff ignoring all whitespace changes except leading whitespace changes
  assert_equal('', diff(['abc def'], ['abc  def '], {iwhite: true}))
  assert_equal("@@ -1 +1 @@\n- abc\n+  xxx\n", diff([' abc'], ['  xxx'], {iwhite: v:true}))
  assert_equal("@@ -1 +1 @@\n- abc\n+  xxx\n", diff([' abc'], ['  xxx'], {iwhite: v:false}))
  assert_equal("@@ -1 +1 @@\n-abc \n+xxx  \n", diff(['abc '], ['xxx  '], {iwhite: v:true}))
  assert_equal("@@ -1 +1 @@\n-abc \n+xxx  \n", diff(['abc '], ['xxx  '], {iwhite: v:false}))

  # diff ignoring all whitespace changes
  assert_equal('', diff(['abc def'], [' abc  def '], {iwhiteall: true}))
  assert_equal("@@ -1 +1 @@\n- abc \n+  xxx  \n", diff([' abc '], ['  xxx  '], {iwhiteall: v:true}))
  assert_equal("@@ -1 +1 @@\n- abc \n+  xxx  \n", diff([' abc '], ['  xxx  '], {iwhiteall: v:false}))

  # diff ignoring trailing whitespace changes
  assert_equal('', diff(['abc'], ['abc  '], {iwhiteeol: true}))

  # diff ignoring blank lines
  assert_equal('', diff(['one', '', '', 'two'], ['one', 'two'], {iblank: true}))
  assert_equal('', diff(['one', 'two'], ['one', '', '', 'two'], {iblank: true}))

  # same string
  assert_equal('', diff(['abc', 'def', 'ghi'], ['abc', 'def', 'ghi']))
  assert_equal('', diff([''], ['']))
  assert_equal('', diff([], []))

  # different xdiff algorithms
  for algo in ['myers', 'minimal', 'patience', 'histogram']
    assert_equal("@@ -1 +1 @@\n- abc \n+  xxx  \n",
      diff([' abc '], ['  xxx  '], {algorithm: algo, output: 'unified'}))
    assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
      diff([' abc '], ['  xxx  '], {algorithm: algo, output: 'indices'}))
  endfor
  assert_equal("@@ -1 +1 @@\n- abc \n+  xxx  \n",
    diff([' abc '], ['  xxx  '], {indent-heuristic: true, output: 'unified'}))
  assert_equal([{from_idx: 0, from_count: 1, to_idx: 0, to_count: 1}],
    diff([' abc '], ['  xxx  '], {indent-heuristic: true, output: 'indices'}))

  # identical strings
  assert_equal('', diff(['111', '222'], ['111', '222'], {output: 'unified'}))
  assert_equal([], diff(['111', '222'], ['111', '222'], {output: 'indices'}))
  assert_equal('', diff([], [], {output: 'unified'}))
  assert_equal([], diff([], [], {output: 'indices'}))

  # Error cases
  assert_fails('call diff({}, ["a"])', 'E1211:')
  assert_fails('call diff(["a"], {})', 'E1211:')
  assert_fails('call diff(["a"], ["a"], [])', 'E1206:')
  assert_fails('call diff(["a"], ["a"], {output: "xyz"})', 'E106: Unsupported diff output format: xyz')
enddef

" vim: shiftwidth=2 sts=2 expandtab
