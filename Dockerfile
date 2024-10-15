# Setting global arguments
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_DEPLOYMENT=true

FROM ruby:3.3-alpine AS build-env

# include global args
ARG BUNDLE_WITHOUT
ARG BUNDLE_DEPLOYMENT

LABEL org.opencontainers.image.authors='pglombardo@hey.com'

# Required packages
RUN apk add --no-cache \
    build-base \
    curl \
    git \
    libc6-compat \
    libpq-dev \
    mariadb-dev \
    nodejs \
    sqlite-dev \
    tzdata \
    yarn

ENV APP_ROOT=/opt/PasswordPusher

WORKDIR ${APP_ROOT}
COPY Gemfile Gemfile.lock package.json yarn.lock ./

ENV RACK_ENV=production RAILS_ENV=production

RUN bundle config set without "${BUNDLE_WITHOUT}" \
    && bundle config set deployment "${BUNDLE_DEPLOYMENT}" \
    && bundle install

# Removing unneccesary files/directories
RUN rm -rf vendor/bundle/ruby/*/cache \
    && rm -rf vendor/bundle/ruby/*/bundler/gems/*/.git \
    && find vendor/bundle/ruby/*/gems/ -name "*.c" -delete \
    && find vendor/bundle/ruby/*/gems/ -name "*.o" -delete

RUN yarn install

COPY ./ ${APP_ROOT}/

# Set DATABASE_URL to sqlite to have a ready
# to use db file for ephemeral configuration
ENV DATABASE_URL=sqlite3:db/db.sqlite3

# Set a default secret_key_base
# For those self-hosting this app, you should
# generate your own secret_key_base and set it
# in your environment.
# 1. Generate a secret_key_base value with:
#    bundle exec rails secret
# 2. Set the secret_key_base in your environment:
#    SECRET_KEY_BASE=<value>
ENV SECRET_KEY_BASE=662e5f1c1f71b78c6fc0455cf72b590aefc7e924bbe356556c8dacd18fa0c6a5d7d4908afc7627bd1d6cb5ce95b610eeb64f538079d1fe07ef3d73b43ac0f8b0

RUN bundle exec bootsnap precompile --gemfile
RUN bundle exec bootsnap precompile app/ lib/
RUN bundle exec rails assets:precompile
RUN bundle exec rake db:setup

################## Build done ##################

FROM ruby:3.3-alpine

# include global args
ARG BUNDLE_WITHOUT
ARG BUNDLE_DEPLOYMENT

LABEL maintainer='pglombardo@hey.com'

# install packages
RUN apk add --no-cache \
    bash \
    libc6-compat \
    libpq \
    mariadb-connector-c \
    nodejs \
    sqlite-dev \
    tzdata

# Create a user and group to run the application
ARG UID=1000
ARG GID=1000

RUN addgroup -g "${GID}" pwpusher \
  && adduser -D -u "${UID}" -G pwpusher pwpusher

ENV LC_CTYPE=UTF-8 LC_ALL=en_US.UTF-8
ENV APP_ROOT=/opt/PasswordPusher
WORKDIR ${APP_ROOT}
ENV RACK_ENV=production RAILS_ENV=production

# Set a default secret_key_base
# For those self-hosting this app, you should
# generate your own secret_key_base and set it
# in your environment.
# 1. Generate a secret_key_base value with:
#    bundle exec rails secret
# 2. Set the secret_key_base in your environment:
#    SECRET_KEY_BASE=<value>
ENV SECRET_KEY_BASE=662e5f1c1f71b78c6fc0455cf72b590aefc7e924bbe356556c8dacd18fa0c6a5d7d4908afc7627bd1d6cb5ce95b610eeb64f538079d1fe07ef3d73b43ac0f8b0

COPY --from=build-env --chown=pwpusher:pwpusher ${APP_ROOT} ${APP_ROOT}
RUN sed -i 's/\r$//' ./containers/docker/entrypoint.sh

RUN bundle config set without "${BUNDLE_WITHOUT}" \
    && bundle config set deployment "${BUNDLE_DEPLOYMENT}"

USER pwpusher
EXPOSE 5100
ENTRYPOINT ["./containers/docker/entrypoint.sh"]