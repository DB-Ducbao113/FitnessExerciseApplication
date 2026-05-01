FROM denoland/deno:2.7.12

ARG FUNCTION_NAME=workouts-start

WORKDIR /app

COPY deno.json ./deno.json
COPY supabase/functions/${FUNCTION_NAME}/deno.json ./function/deno.json
COPY supabase/functions/${FUNCTION_NAME}/index.ts ./function/index.ts

RUN deno cache --config ./function/deno.json ./function/index.ts

EXPOSE 8000

CMD ["run", "--allow-net", "--allow-env", "--config", "./function/deno.json", "./function/index.ts"]
