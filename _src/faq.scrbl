#lang scribble/manual
@title{Racket常见问题 FAQ}
@bold{这里有一些使用Racket的常见问题。 }

@section{}
Q:我如何使用Racket学习SICP?

A:安装Racket(https://download.racket-lang.org/),进入安装目录,使用以下命令:raco pkg install sicp,

等待sicp包安装完成，打开DrRacket（如果已经打开的需要重新启动），将最上面一行换成#lang sicp
@section{}
Q：使用SICP语言如何引用其他库里面的函数？

A：需要使用#%require，(#%require pict) 引用了pict库。
@section{}
Q：Racket语言和Scheme语言有区别吗？

A：Racket语言可以看做Scheme的超集，但还是有一些区别的，总体来说，Racket更好用。
@section{}
Q：我想要设置DrRacket的字体和配色，怎么办？

A：View菜单下的Preference项。
@section{}
Q：DrRacket怎样一键调整缩进？

A：Ctrl + I
@section{}
Q:有哪些常用的DrRacket插件？

files-viewer:文件管理器

DrRacketTheme:设置DrRacket的背景图片

drracket-paredit:更快的编辑速度

drracket-vim-tool:vim的编辑方式
@section{}
Q：Racket下为什么不能使用set-car!和set-cdr!

A：Racket的list是immutable list，不可变。
@section{}
Q：我希望在Racket下面使用eval函数，为什么不行？

A：如果直接使用eval，需在repl下使用，如果想在定义里面使用eval必须先加上这行：
@code{(current-namespace (make-base-namespace))}
@section{}
Q:能不能在DrRacket里面输入unicode字符？

A:可以，比如alpha\@italic{Alt+\}   (α)。