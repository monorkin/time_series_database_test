FROM ruby:3.0.0-alpine AS base

ARG WORKDIR=/app

ENV WORKDIR=$WORKDIR \
    LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
      build-base \
      ruby-dev \
      tzdata \
      postgresql-client \
      postgresql-dev \
      mariadb-dev \
      sqlite-dev \
      sqlite-libs \
      git \
      make \
      less \
      bash \
      curl \
    && rm -rf /var/cache/apk/*

RUN apk add --no-cache --force \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    libcrypto1.1

RUN echo 'gem: --no-rdoc --no-ri' > /etc/gemrc
ENV BUNDLER_VERSION=2.0.1
RUN gem install bundler -v $BUNDLER_VERSION
ENV GEM_HOME="/usr/local/bundle"
ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

WORKDIR $WORKDIR

COPY Gemfile* /app/
RUN bundle install --jobs `expr $$(nproc) - 1` --retry 3
