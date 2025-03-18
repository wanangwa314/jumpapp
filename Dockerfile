# Find eligible builder and runner images on Docker Hub
ARG BUILDER_IMAGE="hexpm/elixir:1.16.2-erlang-26.2.2-debian-bookworm-20240130"
ARG RUNNER_IMAGE="debian:bookworm-20240130"

FROM ${BUILDER_IMAGE} as builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel

RUN mix release

# Start a new build stage for the final image
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Set environment variables
ENV DATABASE_PATH="/data/sqlite/app.db"
ENV PORT=8080
ENV PHX_HOST="jumpapp2.fly.dev"
ENV SECRET_KEY_BASE=""
ENV MIX_ENV="prod"

WORKDIR "/app"
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/jumpapp ./

USER nobody

# Create SQLite data directories
RUN mkdir -p /app/priv/data

# Create the entrypoint script
RUN echo '#!/bin/sh\n\
# Create SQLite directory if it does not exist\n\
mkdir -p /data/sqlite\n\
\n\
# Run migrations\n\
/app/bin/jumpapp eval "Jumpapp.Release.migrate"\n\
\n\
# Start the Phoenix app\n\
exec /app/bin/jumpapp start' > /app/entrypoint.sh \
&& chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]