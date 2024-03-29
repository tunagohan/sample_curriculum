FROM ruby:2.6.1

# 必要なパッケージのインストール
RUN apt-get update -qq && \
  apt-get install -y build-essential libpq-dev

# yarnのインストール
RUN apt-get update && apt-get install -y curl apt-transport-https wget && \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && apt-get install -y yarn

# Nodeのインストール
RUN curl -sL https://deb.nodesource.com/setup_13.x | bash - && \
  apt-get install -y nodejs

# Rails アプリケーションの構成作成
RUN mkdir /app
WORKDIR /app
COPY ./rails_application/Gemfile /app/Gemfile
COPY ./rails_application/Gemfile.lock /app/Gemfile.lock
RUN gem install bundler
RUN bundle install
COPY ./rails_application/ /app

CMD ["rails", "server", "-b", "0.0.0.0"]
