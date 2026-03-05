(in-package #:cl-battlesnake)

;;; --- Server ---

(defvar *snake-instances* nil
  "Hash table mapping paths to snake instances for multi-snake mode.")

(defvar *server* nil
  "The active Clack server handle.")

;;; --- JSON encoding (hand-rolled, responses are fixed-shape) ---

(defun escape-json-string (s)
  "Escape a string for safe JSON embedding."
  (with-output-to-string (out)
    (loop for c across s do
      (case c
        (#\" (write-string "\\\"" out))
        (#\\ (write-string "\\\\" out))
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (t (write-char c out))))))

(defun move-json (direction &optional shout)
  "Build JSON response for a move. DIRECTION is a string like \"up\"."
  (if (and shout (stringp shout) (plusp (length shout)))
      (format nil "{\"move\":\"~A\",\"shout\":\"~A\"}"
              direction (escape-json-string shout))
      (format nil "{\"move\":\"~A\"}" direction)))

(defun encode-snake-info (info-alist)
  "Encode snake-info alist as JSON. Keys are strings."
  (format nil "{~{\"~A\":\"~A\"~^,~}}"
          (loop for (k . v) in info-alist
                collect (escape-json-string k)
                collect (escape-json-string v))))

;;; --- Clack response helpers ---

(defun json-ok (body-string)
  "Return a Clack 200 response with JSON content type."
  (list 200 '(:content-type "application/json") (list body-string)))

(defun json-not-found ()
  "Return a Clack 404 response."
  (list 404 '(:content-type "application/json")
        (list "{\"error\":\"not found\"}")))

;;; --- Route helpers ---

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

(defun ends-with-p (suffix string)
  "Return T if STRING ends with SUFFIX."
  (let ((slen (length suffix))
        (len (length string)))
    (and (>= len slen)
         (string= suffix string :start2 (- len slen)))))

(defun determine-endpoint (path-info)
  "Determine which endpoint a path-info refers to.
   Returns :start, :move, :end, or :info."
  (cond
    ((ends-with-p "/start" path-info) :start)
    ((ends-with-p "/move" path-info) :move)
    ((ends-with-p "/end" path-info) :end)
    ;; Bare endpoints at root: /start, /move, /end
    ((string= path-info "/start") :start)
    ((string= path-info "/move") :move)
    ((string= path-info "/end") :end)
    ;; Everything else is info (including / and /path/)
    (t :info)))

;;; --- Clack App ---

(defun make-app ()
  "Create a Clack application lambda that dispatches requests to snakes."
  (lambda (env)
    (let* ((method (getf env :request-method))
           (path-info (getf env :path-info))
           (snake-path (extract-snake-path path-info))
           (snake (get-snake-for-path snake-path))
           (endpoint (determine-endpoint path-info)))
      (cond
        ;; GET info
        ((and (eq method :GET) (eq endpoint :info))
         (if snake
             (json-ok (encode-snake-info (snake-info snake)))
             (json-not-found)))
        ;; POST start
        ((and (eq method :POST) (eq endpoint :start))
         (if snake
             (let* ((json  (read-json-body env))
                    (state (when json (parse-game-state json))))
               (when state
                 (on-start snake state))
               (json-ok "{\"ok\":\"true\"}"))
             (json-not-found)))
        ;; POST move
        ((and (eq method :POST) (eq endpoint :move))
         (if snake
             (let* ((json  (read-json-body env))
                    (state (when json (parse-game-state json))))
               (if state
                   (multiple-value-bind (direction shout) (on-move snake state)
                     (json-ok (move-json (direction-string (or direction +up+)) shout)))
                   (json-ok (move-json (direction-string +up+)))))
             (json-not-found)))
        ;; POST end
        ((and (eq method :POST) (eq endpoint :end))
         (if snake
             (let* ((json  (read-json-body env))
                    (state (when json (parse-game-state json))))
               (when state
                 (on-end snake state))
               (json-ok "{\"ok\":\"true\"}"))
             (json-not-found)))
        ;; Unknown route
        (t (json-not-found))))))

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

  ;; Start server with Clack + Woo
  (setf *server* (clack:clackup (make-app) :server :woo :port port
                                :use-default-middlewares nil))
  (format t "~&Multi-snake server running on port ~D with ~D snakes~%"
          port (hash-table-count *snake-instances*))
  *server*)

(defun stop-server ()
  "Stop the running Battlesnake server."
  (when *server*
    (clack:stop *server*)
    (setf *server* nil)
    (setf *snake-instances* nil)
    (format t "~&Server stopped.~%")))
