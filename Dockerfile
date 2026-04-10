FROM ruby:4-alpine
RUN apk add --no-cache build-base && apk --no-cache upgrade
RUN addgroup -S app && adduser -S app -G app
USER app
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --no-cache
COPY . .
ENTRYPOINT ["ruby", "stickshifts.rb"]