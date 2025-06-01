ARG RUBY_VERSION=3.3

FROM ruby:${RUBY_VERSION}-bookworm

WORKDIR /app

RUN apt update && apt install -y git make ruby-dev

RUN git config --global --add safe.directory /app


COPY Gemfile .
COPY beautiful-jekyll-theme.gemspec .
COPY Appraisals .

RUN bundle install && bundle exec appraisal install

COPY . .

RUN chown 65534:65534 /app

USER 65534:65534

EXPOSE 4000

ENTRYPOINT ["bundle", "exec", "jekyll", "serve", "-H", "0.0.0.0", "-P", "4000", "--incremental", "--trace"] 