#lang frog/config

;; Called early when Frog launches. Use this to set parameters defined
;; in frog/params.
(define/contract (init)
  (-> any)
  (current-scheme/host "http://www.racket-zh.org")
  (current-title "Racket中文网站")
  (current-author "未知作者"))

;; Called once per post and non-post page, on the contents.
(define/contract (enhance-body xs)
  (-> (listof xexpr/c) (listof xexpr/c))
  ;; Here we pass the xexprs through a series of functions.
  (~> xs
      (syntax-highlight #:python-executable (if (eq? (system-type 'os) 'windows) "python.exe"
                                                "python")
                        #:line-numbers? #t
                        #:css-class "source")
      (auto-embed-tweets #:parents? #t)
      (add-racket-doc-links #:code? #t #:prose? #f)))

;; Called from `raco frog --clean`.
(define/contract (clean)
  (-> any)
  (void))
