FROM ruby:4-alpine@sha256:b99166e463d6547bdccb2457cfd8af0d8b37c79d1fd1bee69cafcfd780e4a497
LABEL org.opencontainers.image.source https://github.com/amichal/stickshifts
LABEL org.opencontainers.image.authors "Aaron Michal"
LABEL org.opencontainers.image.licenses "MIT"

RUN apk add --no-cache build-base && apk --no-cache upgrade

RUN addgroup -S app && adduser -S app -G app
USER app

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --no-cache
COPY . .

ENTRYPOINT ["ruby", "stickshifts.rb"]