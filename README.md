# sample_curriculum

Techpit サンプル実装

今回は rails_application というディレクトリをこの場に作成し
そちらで Docker の実装などを行う。

同じ階層に Docker ファイルを作っても良いが 分かりやすいように今回は分ける方針で行う。

このような構成にすることで Docker リポジトリと Rails リポジトリを分けて開発することが出来るため
メンテが行いやすい。
分離している点から いろいろな Rails アプリケーションに適用することができるメリットがある

## サンプルアプリケーションのクローン

```

$ git clone https://github.com/tunagohan/sample_rails_application rails_application

```

## Docker の構成を作る

### Rails の構成

#### Dockerfile の作成

```

$ vim Dockerfile

```

```

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

```

### docker-compose の作成

```

$ vim docker-compose.yml

```

```

version: "3.2"
services:
  web:
    build:
      context: ./
      dockerfile: ./Dockerfile
    environment:
      RAILS_ENV: development
      MYSQL_USER: root
      MYSQL_PASSWORD:
      MYSQL_HOST: db
      RAILS_SERVE_STATIC_FILES: "false"
    command: bash -c "bundle exec rails s -p 3000 -b '0.0.0.0'"
    tty: true
    stdin_open: true
    depends_on:
      - webpacker
    volumes:
      - ./rails_application/:/app
      - bundle_data:/usr/local/bundle
    ports:
      - "${RAILS_PORT:-3000}:3000"

  webpacker:
    build:
      context: ./
      dockerfile: ./Dockerfile
    command: bundle exec bin/webpack-dev-server
    tty: true
    stdin_open: true
    volumes:
      - ./rails_application/:/app
    ports:
      - "${WEBPACK_PORT:-3035}:3035"

volumes:
  bundle_data:

```

### Database の構成

#### docker-compose.yml の作成

image は公式のものを利用する

```

$ vim docker-compose.yml

```

```

version: "3.2"
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD:-root}"
      MYSQL_DATABASE: "{MYSQL_DATABASE:-test_database}"
      MYSQL_USER: "${MYSQL_USER:-docker}"
      MYSQL_PASSWORD: "${MYSQL_PASSWORD:-docker}"
      TZ: "Asia/Tokyo"
    command: mysqld --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    volumes:
      - mysql_data:/var/lib/mysql
      - ./resouces/my.cnf:/etc/mysql/conf.d/my.cnf
    ports:
      - "${MYSQL_PORT:-3306}:3306"

  web:
    build:
      context: ./
      dockerfile: ./Dockerfile
    environment:
      RAILS_ENV: development
      MYSQL_USER: root
      MYSQL_PASSWORD: root
      MYSQL_HOST: db
      RAILS_SERVE_STATIC_FILES: "false"
    command: bash -c "bundle exec rails s -p 3000 -b '0.0.0.0'"
    tty: true
    stdin_open: true
    depends_on:
      - db
      - webpacker
    volumes:
      - ./rails_application/:/app
      - bundle_data:/usr/local/bundle
    ports:
      - "${RAILS_PORT:-3000}:3000"

  webpacker:
    build:
      context: ./
      dockerfile: ./Dockerfile
    command: bundle exec bin/webpack-dev-server
    tty: true
    stdin_open: true
    volumes:
      - ./rails_application/:/app
    ports:
      - "${WEBPACK_PORT:-3035}:3035"

volumes:
  bundle_data:
  mysql_data:

```

#### mysql 用の cnf の作成

絵文字に対応するために utf8mb4 に変更する

```

$ vim resouces/my.cnf

```

```

[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

[client]
default-character-set=utf8mb4

```

#### rails 側 database.yml の修正

```

$ vim rails_application/config/database.yml

```

```

default: &default
  adapter: mysql2
  encoding: utf8mb4
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV["MYSQL_USER"] %>
  password: <%= ENV["MYSQL_PASSWORD"] %>
  host: <%= ENV["MYSQL_HOST"] %>

development:
  <<: *default
  database: sample_rails_application_development

```

### 既存ポートとバッティングする可能性があるので ENV を編集する

```

$ brew install direnv

```

```

$ direnv edit .

```

```

export MYSQL_PORT=3333
export RAILS_PORT=3332
export WEBPACK_PORT=3331


```

本来であれば gitignore に .envrc を追加するべきなのですがサンプルとして載せておきます。

### build

```

$ docker-compose build

```

### yarn の update

サンプルのアプリケーションは わざと yarn 10 系で行っており、この Docker 構成では 13 系なのでそのままでは動かせない。

なので `--check-files` を行い `update` を行う

```

$ docker-compose run --rm web yarn install --check-files

```

### コンテナ内 Database に migrate

```

$ docker-compose run --rm web bundle exec rails db:create db:migrate db:seed
> > Created database 'sample_rails_application_development'
> > Created database 'sample_rails_application_test'
> > == 20200102071259 CreateBooks: migrating ======================================
> > -- create_table(:books)
> >    -> 0.0125s
> > == 20200102071259 CreateBooks: migrated (0.0127s) =============================
```

### up

```

$ docker-compose up -d

```

表示されます。

大体 30 分程でできました。
