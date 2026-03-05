FROM alpine:3.19 AS builder

RUN apk add --no-cache sbcl git ca-certificates curl libev-dev gcc musl-dev

WORKDIR /tmp
RUN curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive \
         --load quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' && \
    printf '%s\n' '#-quicklisp' \
           '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))' \
           '  (when (probe-file quicklisp-init)' \
           '    (load quicklisp-init)))' > /root/.sbclrc

WORKDIR /app

# Dep layer: only .asd changes trigger quicklisp re-install
COPY cl-battlesnake.asd /app/
RUN sbcl --non-interactive \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(handler-case (ql:quickload :cl-battlesnake) (error () nil))" \
    --eval "(quit)"

# Source layer: code changes only rebuild from here
COPY . /app/

# Build and save compressed core with everything loaded
RUN sbcl --non-interactive \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(ql:quickload :cl-battlesnake/examples)" \
    --eval "(sb-ext:save-lisp-and-die \"/app/battlesnake.core\" :toplevel (lambda () (cl-battlesnake/examples:start-all-snakes :port (parse-integer (or (uiop:getenv \"PORT\") \"8080\"))) (loop (sleep 3600))) :compression t :purify t)"

# Minimal runtime — just SBCL + the core + libev
FROM alpine:3.19

RUN apk add --no-cache sbcl ca-certificates wget libev

WORKDIR /app
COPY --from=builder /app/battlesnake.core /app/

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/random/ || exit 1

CMD ["sbcl", "--noinform", "--disable-debugger", "--dynamic-space-size", "128", "--core", "/app/battlesnake.core"]
