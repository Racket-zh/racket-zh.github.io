    Title: Bindings as Sets of Scopes
    Date: 2018-06-14T14:19:35
    Tags: Macro,Racket
    Authors: Syntacticlsoure
#Introduction
Racket的宏系统的实现被称为Bindings as Sets of Scopes，每个identifier拥有一个代表当前作用域的集合。  
举例说明: 

```racket
(let ([a 1])
  (let ([a 2]))
  a
  )
``` 
外层的a与内层的a作用域不同，也就是两个a不是同一个identifier，我们可以通过free-identifier=?函数判断两个identifier是否是同一个，这将会返回#f。 
如果我们将第一个let代表的作用域记为local1，第二个记作local2的话，那么内层的a所拥有的作用域集是{local1,local2}， 
外层a是{local1}。 

那么racket是如何确定我们返回的a是哪个a呢？ 

为了区别两个a，我们需要一个独一无二的名字，let在绑定变量的时候会将这个identifier和实际绑定的名字联系起来。
let在被展开的时候，会给body部分打上对应的作用域标记。 

因此，我们返回的a的作用域集是{local1,local2}，然后去寻找这个作用域最大子集所代表的identifier（当然名字要一样，这里忽略了rename-transformer的情况），也就是内层的a。 


#宏展开

为了防止不卫生的宏污染我们的变量，我们可以给宏展开中增加的语法结构打上一层作用域标记，这样我们就无法引用到宏内声明的变量了。 

这是通过在宏展开前后翻转一个新的宏作用域(fresh macro-introduction scope)标记来实现的。 





