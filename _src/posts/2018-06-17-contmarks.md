	Title: Continuation Marks的简单实现
	Date: 2018-06-17T09:43:00
	Tags: Racket,Continuation
	Authors: qww6
## 背景

Continuation Marks——Racket的核心特性之一，虽然直接使用它的人也许很少，但是与其衍生物打交道却是很常见的事情。Continuation Marks是一种通用的在调用链上记录信息的方法，其用途非常广泛，Racket中很多想得到的、想不到的功能，都是使用Continuation Marks实现的，这里不作赘述，有兴趣的朋友可以参阅Racket源码。
<!-- more -->

注：不了解Continuation Marks是什么的，见[Racket Reference](https://docs.racket-lang.org/reference/contmarks.html)

Continuation Marks最大的特点在于其对尾调用的敏感性，如下例：

```racket
#lang racket

(define k (make-continuation-mark-key))

(with-continuation-mark k 1
  (begin
    (with-continuation-mark k 2
      (display (continuation-mark-set->list (current-continuation-marks) k)))
    (newline)))
```

这段代码输出`(2 1)`，而当我们使用尾调用的时候：

```racket
#lang racket

(define k (make-continuation-mark-key))

(with-continuation-mark k 1
  (with-continuation-mark k 2
    (displayln (continuation-mark-set->list (current-continuation-marks) k))))
```

仅输出`(2)`，第二个`with-continuation-mark`因为处于前者的tail position，因此替换前者的记录而非新增一条记录。也就是说，我们不需要看内存占用，就能得知一次函数调用是否为尾调用。



## 实现

Racket、Racket-on-Chez以及Pycket对Continuation Marks的实现方式各不相同，但有一个共同点，那就是均与Continuation实现甚至整个Runtime紧密地耦合在一起。因此，这里将介绍一种在Chez Scheme下，完全正交的实现方法，无需对现有的Continuation实现做任何的改动。

这个方法的关键在于一张哈希表：

```scheme
(define *marks* (make-weak-eq-hashtable))
```

是否觉得一头雾水，现在我将其类型写出来(Typed Racket风格)：`(WeakHashTable Continuation (AssocList ContMarkKey Value))`，熟悉Racket及Chez的朋友到这里可能就明白了。(注：这里使用weak-eq-hashtable，因为要保证safe for space)

现在我们来实现`current-continuation-marks`（这里使用了一些Chez的未有文档的api，可以阅读Chez源码作进一步了解）：

```scheme
(define (copy-alist a)
  (map (lambda (slot) (cons (car slot) (cdr slot))) a))

(define (get-marks c)
  (cond
   [(eq? c #%$null-continuation) '()]
   [(eq-hashtable-ref *marks* c #f) =>
    (lambda (v)
      (cons (copy-alist v) (get-marks (#%$continuation-link c))))]
   [else (get-marks (#%$continuation-link c))]))

(define (current-continuation-marks)
  (call/1cc
   (lambda (cc)
     (get-marks cc))))
```

非常直截了当，就是把continuation链上的关联列表聚集起来，但是有一点要注意，因为continuation-mark-set是一种不可变数据结构，因此需要复制整个关联列表（当然也可以current-continuation-marks的时候不复制，而是with-continuation-mark的时候复制）。所以这里`ContMarkSet` 等于 `(Listof (AssocList ContMarkKey Value))`

然后就是`with-continuation-mark`了，这里我们利用同一tail position的Continuation的pointer equality来检测尾调用：

```scheme
(define-syntax with-continuation-mark
  (syntax-rules ()
    [(_ key-expr val-expr result-expr)
     (let ([k key-expr] [v val-expr])
       (call/1cc
        (lambda (cc)
          (define cell (eq-hashtable-cell *marks* cc #f))
          (cond [(cdr cell) =>
                 (lambda (a)
                   (cond
                    [(assq k a) => (lambda (slot) (set-cdr! slot v))]
                    [else (set-cdr! cell (cons (cons k v) a))]))]
                [else (set-cdr! cell (list (cons k v)))])
          result-expr)))]))
```

再下来就是`make-continuation-mark-key`，为了方便我们这里直接用gensym：

```scheme
(define make-continuation-mark-key
  (case-lambda
    [() (gensym)]
    [(sym) (gensym (symbol->string sym))]))
```

`continuation-mark-set->list`，非常简单：

```scheme
(define (continuation-mark-set->list mark-set key-v)
  (let loop ([l mark-set])
    (cond
     [(null? l) '()]
     [(assq key-v (car l)) =>
      (lambda (slot) (cons (cdr slot) (loop (cdr l))))]
     [else (loop (cdr l))])))
```

`(continuation-mark-set-first mark-set key-v none-v)`等价于`(let ([v (continuation-mark-set->list (or mark-set (current-continuation-marks)) key-v)]) (if (null? v) none-v (car v)))`，不过我们可以实现的更直接一点，消去一些临时的数据结构：

```scheme
(define continuation-mark-set-first
  (case-lambda
    [(mark-set key-v)
     (continuation-mark-set-first mark-set key-v #f)]
    [(mark-set key-v none-v)
     (if mark-set
         (let loop ([m mark-set])
           (cond
            [(null? m) none-v]
            [(assq key-v (car m)) => cdr]
            [else (loop (cdr m))]))
         (call/1cc
          (lambda (cc)
            (let loop ([cc cc])
              (cond
               [(eq? cc #%$null-continuation) none-v]
               [(eq-hashtable-ref *marks* cc #f) =>
                (lambda (v)
                  (cond
                   [(assq key-v v) => cdr]
                   [else (loop (#%$continuation-link cc))]))]
               [else (loop (#%$continuation-link cc))])))))]))
```

然后就是`continuation-mark-set->list*`以及`call-with-immediate-continuation-mark`了：

```scheme
(define continuation-mark-set->list*
  (case-lambda
    [(mark-set key-list)
     (continuation-mark-set->list* mark-set key-list #f)]
    [(mark-set key-list none-v)
     (define len (length key-list))
     (define (get-key k a vec pos)
       (cond
        [(assq k a) => (lambda (v) (vector-set! vec pos (cdr v)))]
        [else (vector-set! vec pos none-v)]))
     (define (get-key-list a)
       (define vec (make-vector len))
       (let loop ([l key-list] [i 0])
         (cond
          [(null? l) vec]
          [else (get-key (car l) a vec i)
                (loop (cdr l) (+ i 1))])))
     (map get-key-list mark-set)]))

(define call-with-immediate-continuation-mark
  (case-lambda
    [(key-v proc)
     (call-with-immediate-continuation-mark key-v proc #f)]
    [(key-v proc default-v)
     (call/1cc
      (lambda (cc)
        (let loop ([cc cc])
          (cond
           [(eq? cc #%$null-continuation) (proc default-v)]
           [(eq-hashtable-ref *marks* cc #f) =>
            (lambda (v)
              (cond
               [(assq key-v v) => (lambda (slot) (proc (cdr slot)))]
               [else (proc default-v)]))]
           [else (loop (#%$continuation-link cc))]))))]))
```

好了，这样一来主要的api就实现完毕了。

## 试用

来试用下吧：

```scheme
(define (test1)
  (define k (make-continuation-mark-key))
  (with-continuation-mark
   k 1
   (begin
     (with-continuation-mark
      k 2
      (display (continuation-mark-set->list (current-continuation-marks) k)))
     (newline))))

(define (test2)
  (define k (make-continuation-mark-key))
  (with-continuation-mark
   k 1
   (with-continuation-mark
    k 2
    (begin
      (display (continuation-mark-set->list (current-continuation-marks) k))
      (newline)))))

(define (test3)
  (define k1 (make-continuation-mark-key))
  (define k2 (make-continuation-mark-key))
  (with-continuation-mark
   k1 1
   (begin
     (with-continuation-mark
      k2 2
      (with-continuation-mark
       k1 3
       (display (continuation-mark-set->list* (current-continuation-marks) (list k1 k2) #f))))
     (newline))))
```

输出:

```scheme
> (test1)
(2 1)
> (test2)
(2)
> (test3)
(#(3 2) #(1 #f))

```

然后再来试一下用Continuation Marks实现Parameter：

```scheme
(define parameterization-key (make-continuation-mark-key))

(define (make-cm-parameter v)
  (let ([k (list 'key)]
        [none (list 'none)])
    (case-lambda
      [()
       (define l (continuation-mark-set->list (current-continuation-marks)
                                              parameterization-key))
       (let loop ([l l])
         (if (null? l)
             v
             (let ([v (eq-hashtable-ref (car l) k none)])
               (if (eq? v none)
                   (loop (cdr l))
                   v))))]
      [(new-v)
       (cond
        [(continuation-mark-set-first #f parameterization-key #f) =>
         (lambda (p)
           (eq-hashtable-set! p k new-v))]
        [else (set! v new-v)])])))

(define-syntax (cm-parameterize stx)
  (syntax-case stx ()
    [(_ ([key value] ...) body body* ...)
     (with-syntax ([(k ...) (generate-temporaries #'(key ...))]
                   [(v ...) (generate-temporaries #'(value ...))])
       #'(let ([k key] ...)
           (let ([v value] ...)
             (with-continuation-mark
              parameterization-key (make-eq-hashtable)
              (k v) ...
              (let ()
                body
                body* ...)))))]))
```

试用：

```scheme
(define (test-pm)
  (define p (make-cm-parameter 1))
  (printf "~a~%" (p))
  (cm-parameterize
   ([p 2])
   (printf "~a~%" (p))
   (p 3)
   (printf "~a~%" (p)))
  (printf "~a~%" (p)))
```

输出：

```scheme
> (test-pm)
1
2
3
1
> 
```

那么这个用Continuation Marks实现的cm-parameter和Chez原生的用dynamic-wind和set!实现的parameter有什么差别呢？运行以下函数，你将体会到他们的不同：

```scheme
(define (test-loop1)
  (define p (make-parameter #f))
  (let loop ()
    (parameterize ([p #t])
      (loop))))

(define (test-loop2)
  (define p (make-cm-parameter #f))
  (let loop ()
    (cm-parameterize ([p #t])
      (loop))))
```

## 小结

以上就是Continuation Marks的一种简单实现方法。

当然它可以改进的地方还有很多，可以将关联列表改为weak-eq-hashtable，进一步提高space safety；可以对哈希表加锁，适应多线程环境；可以把一些数据结构用record封装，实现`continuation-mark-key?`和`continuation-mark-set?`等。这里为了简明不进行这些修改。