(in-package #:cl-battlesnake/test)

(def-suite server-tests :in battlesnake-tests
  :description "HTTP integration tests against the live server")

(in-suite server-tests)

;;; --- Test snake for server tests ---

(defsnake test-always-up
  (:name "Always Up" :color "#ffffff" :head "default" :tail "default"
   :author "test")
  (:move (state)
    (declare (ignore state))
    (values +up+ "Going up!")))

;;; --- Server lifecycle helper ---

(defvar *test-port* 18923)

(defmacro with-test-server ((snake-class &key (port '*test-port*)) &body body)
  "Start a server for SNAKE-CLASS, run BODY, then stop. Binds *test-port*."
  (let ((server (gensym "SERVER")))
    `(let ((,server nil))
       (unwind-protect
            (progn
              (setf ,server (start-server ',snake-class :port ,port))
              ;; Give hunchentoot a moment to bind
              (sleep 0.2)
              ,@body)
         (when ,server
           (stop-server))))))

(defun test-url (path)
  (format nil "http://127.0.0.1:~D~A" *test-port* path))

(defun post-json (path json-string)
  "POST a JSON string to the test server, return parsed response."
  (multiple-value-bind (body status)
      (dex:post (test-url path)
                :content json-string
                :headers '(("Content-Type" . "application/json")))
    (values (com.inuoe.jzon:parse body) status)))

(defun get-json (path)
  "GET from the test server, return parsed response."
  (multiple-value-bind (body status)
      (dex:get (test-url path))
    (values (com.inuoe.jzon:parse body) status)))

;;; --- Tests ---

(test server-get-root
  "GET / returns snake customization info."
  (with-test-server (test-always-up)
    (multiple-value-bind (response status) (get-json "/")
      (is (= 200 status))
      (is (string= "1" (gethash "apiversion" response)))
      (is (string= "#ffffff" (gethash "color" response)))
      (is (string= "test" (gethash "author" response))))))

(test server-post-start
  "POST /start returns 200."
  (with-test-server (test-always-up)
    (multiple-value-bind (response status)
        (post-json "/start" (sample-move-json))
      (is (= 200 status))
      (is (hash-table-p response)))))

(test server-post-move
  "POST /move returns a valid direction."
  (with-test-server (test-always-up)
    (multiple-value-bind (response status)
        (post-json "/move" (sample-move-json))
      (is (= 200 status))
      (is (string= "up" (gethash "move" response)))
      (is (string= "Going up!" (gethash "shout" response))))))

(test server-post-end
  "POST /end returns 200."
  (with-test-server (test-always-up)
    (multiple-value-bind (response status)
        (post-json "/end" (sample-move-json))
      (is (= 200 status)))))

(test server-move-without-body
  "POST /move with empty body defaults to 'up'."
  (with-test-server (test-always-up)
    (multiple-value-bind (response status)
        (post-json "/move" "")
      (is (= 200 status))
      (is (string= "up" (gethash "move" response))))))

;;; --- Multi-snake server tests ---

(defsnake test-always-down
  (:name "Always Down" :color "#000000" :head "default" :tail "default"
   :author "test")
  (:move (state)
    (declare (ignore state))
    (values +down+ "Going down!")))

(defsnake test-always-left
  (:name "Always Left" :color "#ff0000" :head "default" :tail "default"
   :author "test")
  (:move (state)
    (declare (ignore state))
    (values +left+ "Going left!")))

(defmacro with-multi-snake-server (snake-configs &body body)
  "Start a multi-snake server with SNAKE-CONFIGS, run BODY, then stop.
   SNAKE-CONFIGS is a list of (path . snake-class) pairs."
  (let ((server (gensym "SERVER")))
    `(let ((,server nil))
       (unwind-protect
            (progn
              (setf ,server (cl-battlesnake:start-multi-snake-server ',snake-configs
                                                                     :port *test-port*))
              ;; Give hunchentoot a moment to bind
              (sleep 0.2)
              ,@body)
         (when ,server
           (cl-battlesnake:stop-server))))))

(test multi-snake-server-basic
  "Test that multiple snakes can run on different paths."
  (with-multi-snake-server (("/up" . test-always-up)
                            ("/down" . test-always-down)
                            ("/left" . test-always-left))
    ;; GET each snake's info endpoint
    (multiple-value-bind (resp1 status1) (get-json "/up/")
      (is (= 200 status1))
      (is (string= "#ffffff" (gethash "color" resp1)))
      (is (string= "test" (gethash "author" resp1))))

    (multiple-value-bind (resp2 status2) (get-json "/down/")
      (is (= 200 status2))
      (is (string= "#000000" (gethash "color" resp2)))
      (is (string= "test" (gethash "author" resp2))))

    (multiple-value-bind (resp3 status3) (get-json "/left/")
      (is (= 200 status3))
      (is (string= "#ff0000" (gethash "color" resp3)))
      (is (string= "test" (gethash "author" resp3))))))

(test multi-snake-routing
  "Test path routing works correctly."
  (with-multi-snake-server (("/path1" . test-always-up)
                            ("/path2" . test-always-down))
    ;; Call /path1/move - should return "up"
    (multiple-value-bind (resp1 status1)
        (post-json "/path1/move" (sample-move-json))
      (is (= 200 status1))
      (is (string= "up" (gethash "move" resp1)))
      (is (string= "Going up!" (gethash "shout" resp1))))

    ;; Call /path2/move - should return "down"
    (multiple-value-bind (resp2 status2)
        (post-json "/path2/move" (sample-move-json))
      (is (= 200 status2))
      (is (string= "down" (gethash "move" resp2)))
      (is (string= "Going down!" (gethash "shout" resp2))))))

(test multi-snake-isolation
  "Test snakes don't interfere with each other."
  (with-multi-snake-server (("/up" . test-always-up)
                            ("/down" . test-always-down))
    ;; Call /up/move multiple times - always returns "up"
    (dotimes (i 3)
      (multiple-value-bind (resp status)
          (post-json "/up/move" (sample-move-json))
        (is (= 200 status))
        (is (string= "up" (gethash "move" resp)))))

    ;; Call /down/move multiple times - always returns "down"
    (dotimes (i 3)
      (multiple-value-bind (resp status)
          (post-json "/down/move" (sample-move-json))
        (is (= 200 status))
        (is (string= "down" (gethash "move" resp)))))

    ;; Interleave calls - should still be independent
    (multiple-value-bind (resp1 status1)
        (post-json "/up/move" (sample-move-json))
      (is (= 200 status1))
      (is (string= "up" (gethash "move" resp1))))

    (multiple-value-bind (resp2 status2)
        (post-json "/down/move" (sample-move-json))
      (is (= 200 status2))
      (is (string= "down" (gethash "move" resp2))))))

(test multi-snake-unknown-path
  "Test 404 for unknown paths."
  (with-multi-snake-server (("/up" . test-always-up))
    ;; Try to access non-existent path
    (handler-case
        (progn
          (get-json "/nonexistent/")
          (fail "Expected 404 error but got success"))
      (dex:http-request-not-found ()
        ;; Expected - this is the success case
        (pass)))))

(test multi-snake-all-endpoints
  "Test all endpoints work on each path."
  (with-multi-snake-server (("/snake1" . test-always-up)
                            ("/snake2" . test-always-down))
    ;; Test all endpoints for /snake1
    (multiple-value-bind (info-resp info-status) (get-json "/snake1/")
      (is (= 200 info-status))
      (is (string= "1" (gethash "apiversion" info-resp)))
      (is (string= "#ffffff" (gethash "color" info-resp))))

    (multiple-value-bind (start-resp start-status)
        (post-json "/snake1/start" (sample-move-json))
      (is (= 200 start-status))
      (is (hash-table-p start-resp)))

    (multiple-value-bind (move-resp move-status)
        (post-json "/snake1/move" (sample-move-json))
      (is (= 200 move-status))
      (is (string= "up" (gethash "move" move-resp))))

    (multiple-value-bind (end-resp end-status)
        (post-json "/snake1/end" (sample-move-json))
      (is (= 200 end-status)))

    ;; Test all endpoints for /snake2
    (multiple-value-bind (info-resp info-status) (get-json "/snake2/")
      (is (= 200 info-status))
      (is (string= "1" (gethash "apiversion" info-resp)))
      (is (string= "#000000" (gethash "color" info-resp))))

    (multiple-value-bind (start-resp start-status)
        (post-json "/snake2/start" (sample-move-json))
      (is (= 200 start-status))
      (is (hash-table-p start-resp)))

    (multiple-value-bind (move-resp move-status)
        (post-json "/snake2/move" (sample-move-json))
      (is (= 200 move-status))
      (is (string= "down" (gethash "move" move-resp))))

    (multiple-value-bind (end-resp end-status)
        (post-json "/snake2/end" (sample-move-json))
      (is (= 200 end-status)))))
