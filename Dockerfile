# --- Builder ---
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    sbcl git ca-certificates curl libev-dev gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive \
         --load quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' && \
    printf '%s\n' '#-quicklisp' \
           '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))' \
           '  (when (probe-file quicklisp-init)' \
           '    (load quicklisp-init)))' > /root/.sbclrc

# Pre-fetch all third-party deps before copying source.
# This layer only invalidates when the dep list in the asd changes.
# We load a stub asd that declares only the external deps.
RUN sbcl --non-interactive \
    --eval "(ql:quickload '(\"clack\" \"woo\" \"com.inuoe.jzon\" \"alexandria\"))" \
    --eval "(quit)"

WORKDIR /app
COPY . /app/

RUN sbcl --non-interactive \
    --eval "(push (truename \".\") asdf:*central-registry*)" \
    --eval "(ql:quickload :cl-battlesnake/examples)" \
    --eval "(sb-ext:save-lisp-and-die \"/app/battlesnake\" \
               :toplevel (lambda () \
                 (cl-battlesnake/examples:start-all-snakes \
                   :port (parse-integer (or (uiop:getenv \"PORT\") \"8080\"))) \
                 (loop (sleep 3600))) \
               :executable t \
               :compression t \
               :purify t \
               :save-runtime-options t)"

# --- Runner ---
# Single self-contained binary — no SBCL, no Quicklisp, no source.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget libev4 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/battlesnake .

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/random/ || exit 1

ENTRYPOINT ["./battlesnake", "--dynamic-space-size", "128", "--lose-on-corruption"]
