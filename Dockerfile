FROM alpine:3.19 AS builder

RUN apk add --no-cache sbcl git ca-certificates curl

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
COPY . /app/

RUN sbcl --non-interactive \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(ql:quickload :cl-battlesnake/examples)" \
    --eval "(quit)"

FROM alpine:3.19

RUN apk add --no-cache sbcl ca-certificates wget

COPY --from=builder /root/quicklisp /root/quicklisp
COPY --from=builder /root/.sbclrc /root/.sbclrc

WORKDIR /app
COPY . /app/

ENV PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/random/ || exit 1

CMD sbcl --noinform --disable-debugger \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(ql:quickload :cl-battlesnake/examples :silent t)" \
    --eval "(cl-battlesnake/examples:start-all-snakes \
               :port (parse-integer (or (uiop:getenv \"PORT\") \"8080\")))" \
    --eval "(loop (sleep 1))"
