(in-package #:cl-battlesnake)

;;; --- Server ---

(defvar *snake-instances* nil
  "Hash table mapping paths to snake instances for multi-snake mode.")

(defvar *server* nil
  "The active hunchentoot acceptor.")

(defun json-response (data)
  "Set content type to JSON and return encoded string."
  (setf (hunchentoot:content-type*) "application/json")
  (com.inuoe.jzon:stringify data))

(defun alist-to-hash (alist)
  "Convert an alist to a hash-table for jzon serialization."
  (let ((ht (make-hash-table :test 'equal)))
    (loop for (k . v) in alist do (setf (gethash k ht) v))
    ht))

;;; --- Route handlers ---

(defun extract-snake-path (uri)
  "Extract the snake path prefix from a URI.
   Examples: /random/move -> /random, /move -> /, / -> /"
  (let* ((trimmed (string-trim "/" uri))
         (slash-pos (position #\/ trimmed)))
    (cond
      ;; Root path: / or /start or /move or /end
      ((or (zerop (length trimmed))
           (and (null slash-pos)
                (member trimmed '("start" "move" "end") :test #'string=)))
       "/")
      ;; Path-based: /random/move -> /random
      (slash-pos
       (concatenate 'string "/" (subseq trimmed 0 slash-pos)))
      ;; Single segment: /random -> /random
      (t
       (concatenate 'string "/" trimmed)))))

(defun get-snake-for-path (path)
  "Get the snake instance for a given path from *snake-instances*."
  (when (and *snake-instances* path)
    (gethash path *snake-instances*)))

(defun handle-multi-index ()
  "GET /<path>/ - Return snake customization info."
  (let* ((uri (hunchentoot:request-uri*))
         (snake-path (extract-snake-path uri))
         (snake (get-snake-for-path snake-path)))
    (if snake
        (json-response (alist-to-hash (snake-info snake)))
        (progn
          (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
          (json-response (alist-to-hash '(("error" . "Snake not found"))))))))

(defun handle-multi-start ()
  "POST /<path>/start - Game is starting."
  (let* ((uri (hunchentoot:request-uri*))
         (snake-path (extract-snake-path uri))
         (snake (get-snake-for-path snake-path)))
    (if snake
        (let* ((json  (read-json-body))
               (state (when json (parse-game-state json))))
          (when state
            (on-start snake state))
          (json-response (alist-to-hash '(("ok" . "true")))))
        (progn
          (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
          (json-response (alist-to-hash '(("error" . "Snake not found"))))))))

(defun handle-multi-move ()
  "POST /<path>/move - Return move."
  (let* ((uri (hunchentoot:request-uri*))
         (snake-path (extract-snake-path uri))
         (snake (get-snake-for-path snake-path)))
    (if snake
        (let* ((json  (read-json-body))
               (state (when json (parse-game-state json))))
          (if state
              (multiple-value-bind (direction shout) (on-move snake state)
                (let ((response `(("move" . ,(direction-string (or direction +up+))))))
                  (when (and shout (stringp shout) (plusp (length shout)))
                    (push (cons "shout" shout) response))
                  (json-response (alist-to-hash response))))
              (json-response (alist-to-hash `(("move" . ,(direction-string +up+)))))))
        (progn
          (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
          (json-response (alist-to-hash '(("error" . "Snake not found"))))))))

(defun handle-multi-end ()
  "POST /<path>/end - Game has ended."
  (let* ((uri (hunchentoot:request-uri*))
         (snake-path (extract-snake-path uri))
         (snake (get-snake-for-path snake-path)))
    (if snake
        (let* ((json  (read-json-body))
               (state (when json (parse-game-state json))))
          (when state
            (on-end snake state))
          (json-response (alist-to-hash '(("ok" . "true")))))
        (progn
          (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
          (json-response (alist-to-hash '(("error" . "Snake not found"))))))))

;;; --- Dispatch ---

(defun make-multi-snake-dispatch-table ()
  "Create Hunchentoot dispatch table for multi-snake mode with path prefixes."
  (list
   ;; Match /<path>/ or just / (trailing slash required for info endpoint)
   (hunchentoot:create-regex-dispatcher "^/([^/]+/)?$" 'handle-multi-index)
   ;; Match /<path>/start or /start
   (hunchentoot:create-regex-dispatcher "^/([^/]+/)?start$" 'handle-multi-start)
   ;; Match /<path>/move or /move
   (hunchentoot:create-regex-dispatcher "^/([^/]+/)?move$" 'handle-multi-move)
   ;; Match /<path>/end or /end
   (hunchentoot:create-regex-dispatcher "^/([^/]+/)?end$" 'handle-multi-end)))

;;; --- Start / Stop ---

(defun start-server (snake-class &key (port 8080))
  "Start a Battlesnake server with SNAKE-CLASS at root path (/).
   Convenience wrapper around start-multi-snake-server."
  (start-multi-snake-server `(("/" . ,snake-class)) :port port))

(defun start-multi-snake-server (snake-configs &key (port 8080))
  "Start a Battlesnake server hosting multiple snakes on different paths.
   SNAKE-CONFIGS is a list of (path . snake-class) pairs, e.g.:
   '((\"/random\" . random-snake) (\"/hungry\" . hungry-snake))"
  (when *server*
    (format t "~&Stopping existing server...~%")
    (stop-server))

  ;; Create snake instances for each path
  (setf *snake-instances* (make-hash-table :test 'equal))
  (loop for (path . snake-class) in snake-configs
        for instance = (make-instance snake-class)
        do (setf (gethash path *snake-instances*) instance)
           (format t "~&Registered snake '~A' at path ~A~%"
                   (snake-info-name instance) path))

  ;; Start server with multi-snake dispatch table
  (setf *server* (make-instance 'hunchentoot:easy-acceptor :port port))
  (setf hunchentoot:*dispatch-table* (make-multi-snake-dispatch-table))
  (hunchentoot:start *server*)
  (format t "~&Multi-snake server running on port ~D with ~D snakes~%"
          port (hash-table-count *snake-instances*))
  *server*)

(defun stop-server ()
  "Stop the running Battlesnake server."
  (when *server*
    (hunchentoot:stop *server*)
    (setf *server* nil)
    (setf *snake-instances* nil)
    (format t "~&Server stopped.~%")))
