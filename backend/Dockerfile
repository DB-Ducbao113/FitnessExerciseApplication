FROM denoland/deno:2.9.7@sha256:fa335acdf6b72106eda2cb6a8cb5f4187e7630e357467489db4b2e7352d5e432

ARG FUNCTION_NAME=workouts-start

WORKDIR /app

COPY deno.json ./deno.json
COPY supabase/functions/_shared ./_shared
COPY supabase/functions/${FUNCTION_NAME}/deno.json ./function/deno.json
COPY supabase/functions/${FUNCTION_NAME}/index.ts ./function/index.ts

RUN deno cache --config ./function/deno.json ./function/index.ts

EXPOSE 8000

USER deno

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["deno", "eval", "--allow-net=127.0.0.1:8000", "fetch('http://127.0.0.1:8000/', {method:'OPTIONS'}).then((r) => { if (r.status >= 500) Deno.exit(1); }).catch(() => Deno.exit(1));"]

CMD ["run", "--allow-net", "--allow-env", "--config", "./function/deno.json", "./function/index.ts"]
