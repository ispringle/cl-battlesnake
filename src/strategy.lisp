(in-package #:cl-battlesnake)

;;; --- Strategy Protocol ---
;;;
;;; Implement a battlesnake by defining a class and specializing the
;;; generic functions below. DEFSNAKE macro simplifies this.

(defclass battlesnake ()
  ((name   :initarg :name   :accessor snake-info-name   :initform "CL Snake")
   (author :initarg :author :accessor snake-info-author :initform "")
   (color  :initarg :color  :accessor snake-info-color  :initform "#888888")
   (head   :initarg :head   :accessor snake-info-head   :initform "default")
   (tail   :initarg :tail   :accessor snake-info-tail   :initform "default")))

(defgeneric snake-info (snake)
  (:documentation "Return customization info as a plist for GET /.")
  (:method ((s battlesnake))
    `(("apiversion" . "1")
      ("author"     . ,(snake-info-author s))
      ("color"      . ,(snake-info-color s))
      ("head"       . ,(snake-info-head s))
      ("tail"       . ,(snake-info-tail s)))))

(defgeneric on-start (snake state)
  (:documentation "Called at game start. Return value ignored.")
  (:method ((s battlesnake) state)
    (declare (ignore s state))
    nil))

(defgeneric on-move (snake state)
  (:documentation "Called each turn. Return a direction string, optionally a shout as second value.")
  (:method ((s battlesnake) state)
    (let* ((bv (safe-moves state))
           (moves (safe-moves-list bv)))
      (if (plusp (safe-moves-count bv))
          (nth (random (length moves)) moves)
          +up+))))

(defgeneric on-end (snake state)
  (:documentation "Called when game ends. Return value ignored.")
  (:method ((s battlesnake) state)
    (declare (ignore s state))
    nil))

;;; --- DEFSNAKE macro ---

(defmacro defsnake (class-name (&rest appearance) &body options)
  "Define a battlesnake class with appearance and strategy methods.

Usage:
  (defsnake my-snake
    (:name \"Snakey\" :color \"#00ff00\" :head \"fang\" :tail \"bolt\"
     :author \"me\")
    (:move (state)
      (let ((moves (safe-moves-list (safe-moves state))))
        (or (first moves) +up+)))
    (:start (state) ...)   ; optional
    (:end (state) ...))    ; optional"
  (let ((move-form  (cdr (assoc :move options)))
        (start-form (cdr (assoc :start options)))
        (end-form   (cdr (assoc :end options))))
    `(progn
       (defclass ,class-name (battlesnake) ()
         (:default-initargs
          ,@(loop for (k v) on appearance by #'cddr
                  collect k collect v)))
       ,@(when move-form
           (destructuring-bind ((state-var) &body body) move-form
             `((defmethod on-move ((snake ,class-name) ,state-var)
                 (declare (ignorable snake))
                 ,@body))))
       ,@(when start-form
           (destructuring-bind ((state-var) &body body) start-form
             `((defmethod on-start ((snake ,class-name) ,state-var)
                 (declare (ignorable snake))
                 ,@body))))
       ,@(when end-form
           (destructuring-bind ((state-var) &body body) end-form
             `((defmethod on-end ((snake ,class-name) ,state-var)
                 (declare (ignorable snake))
                 ,@body))))
       ',class-name)))
