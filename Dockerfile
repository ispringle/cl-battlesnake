FROM fukamachi/sbcl:latest-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app
RUN sbcl --non-interactive \
    --eval "(ql:quickload :quicklisp)" \
    --eval "(ql:add-to-init-file)" || true

COPY . /app/

RUN sbcl --non-interactive \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(ql:quickload :cl-battlesnake/examples)" \
    --eval "(quit)"

FROM fukamachi/sbcl:latest-alpine

RUN apk add --no-cache ca-certificates

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
