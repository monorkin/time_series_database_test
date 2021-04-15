FROM ruby:3.0.0-alpine AS base

ARG WORKDIR=/app

ENV WORKDIR=$WORKDIR \
    LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
      ruby-dev \
      tzdata \
      postgresql-client \
      postgresql-dev \
      mariadb-dev \
      sqlite-dev \
      sqlite-libs \
      make \
      less \
      bash \
      curl \
    && rm -rf /var/cache/apk/*

WORKDIR $WORKDIR
