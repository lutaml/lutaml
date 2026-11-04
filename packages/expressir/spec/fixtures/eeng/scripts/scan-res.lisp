;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Package: CL-USER; Base: 10 -*-

(in-package :CL-USER)

(defun scan-dir (dir)
  (setf dir (truename dir))
  (labels ((cvs-p (dir)
             (let ((name (first (last (pathname-directory dir))))
                   path)
               (setf path (make-pathname :name name :type "exp" :defaults dir))
               (format t "~&;; Scanning ~A~%" path)
               (with-open-file (in path :direction :input)
                 (loop repeat 10
                   as line = (read-line in nil nil)
                   if (search "$Id: " line)
                   do (return-from cvs-p t)))))
           )
    (format t "~&Writing missing-cvs.lst~%")
    (with-open-file (out (make-pathname :name "missing-cvs" :type "lst" :defaults dir)
                         :direction :output :if-exists :supersede
                         :if-does-not-exist :create)
      (loop for path in (directory (make-pathname :name :wild :defaults dir))
        as name = (unless (pathname-name path) (first (last (pathname-directory path))))
        as cvs-p = (when (and name (not (string-equal name "CVS"))
                              (probe-file (make-pathname :name name :type "exp"
                                                         :directory (list :relative name)
                                                         :defaults (truename "./"))))
                     (cvs-p (merge-pathnames (make-pathname :directory (list :relative name)
                                                            :defaults (truename "./"))
                                             (truename "./"))))
        when (and name (null cvs-p)) do (princ name out) (terpri out)))
    (format t "~&***** Done *****~%")))

(scan-dir "./")
