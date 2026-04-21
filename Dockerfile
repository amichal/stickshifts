FROM ruby:4-alpine@sha256:8c5f23c01573a3ef642f6a2f37bfee58b8613eb6782a745df5c1b5bf634180d2
LABEL org.opencontainers.image.source=https://github.com/amichal/stickshifts
LABEL org.opencontainers.image.authors="Aaron Michal"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="A silly toy project that screen-scrapes a old page to see if I could buy a stick-shift car in 2018."

RUN apk add --no-cache build-base && apk --no-cache upgrade

RUN addgroup -S app && adduser -S app -G app
USER app

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --no-cache
COPY . .

ENTRYPOINT ["ruby", "stickshifts.rb"]