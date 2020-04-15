#!/bin/bash

PACKAGELIST+=(autoconf)
PACKAGELIST+=(automake)
PACKAGELIST+=(bison)
PACKAGELIST+=(build-essential)
PACKAGELIST+=(curl)
PACKAGELIST+=(g++)
PACKAGELIST+=(gawk)
PACKAGELIST+=(gcc)
PACKAGELIST+=(git)
PACKAGELIST+=(gnupg2)
PACKAGELIST+=(libc6-dev)
PACKAGELIST+=(libffi-dev)
PACKAGELIST+=(libgdbm-dev)
PACKAGELIST+=(libgmp-dev)
PACKAGELIST+=(liblzma-dev)
PACKAGELIST+=(libncurses5-dev)
PACKAGELIST+=(libpq-dev)
PACKAGELIST+=(libreadline-dev)
PACKAGELIST+=(libsqlite3-dev)
PACKAGELIST+=(libssl-dev)
PACKAGELIST+=(libtool)
PACKAGELIST+=(libyaml-dev)
PACKAGELIST+=(make)
PACKAGELIST+=(nginx-light)
PACKAGELIST+=(nodejs)
PACKAGELIST+=(npm)
PACKAGELIST+=(patch)
PACKAGELIST+=(pkg-config)
PACKAGELIST+=(postgresql-11)
PACKAGELIST+=(pwgen)
PACKAGELIST+=(ruby-dev)
PACKAGELIST+=(ruby-rails)
PACKAGELIST+=(sqlite3)
PACKAGELIST+=(zlib1g-dev)

apt update

apt install -y --no-install-recommends ${PACKAGELIST[@]}

# install rvm

gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

rvm install 2.6

# get the code 
cd ~www-data/

git clone https://github.com/inklewriter/freeinklewriter

cd freeinklewriter/


cat > /etc/postgresql/11/main/pg_hba.conf << HEREDOC
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
HEREDOC
su postgres -c " psql -c \" CREATE ROLE www WITH CREATEDB LOGIN PASSWORD  'inklewriter' ; \" "
su postgres -c " createdb inklewriter_prod -O www"
service postgresql restart

cat >/etc/systemd/system/inklewriter.service << HEREDOC
[Unit]
Description=Inklewriter Server
Requires=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/freeinklewriter
ExecStart=/bin/bash -lc 'RAILS_ENV=production PORT=8080 bundle exec puma -C config/puma.rb'
TimeoutSec=30
RestartSec=15s
Restart=always

[Install]
WantedBy=multi-user.target
HEREDOC

## Rails configuration

cat > config/database.yml << HEREDOC
default: &default
        adapter: postgresql
        encoding: unicode
        pool: 5
        username: www
        password: inklewriter
        host: 127.0.0.1
development:
  <<: *default
  database: inklewriter_dev
# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  <<: *default
  database: inklewriter_test

production:
  <<: *default
  database: inklewriter_prod
HEREDOC


cat >config/secrets.yml  << HEREDOC
production:
  secret_key_base: "inklewriter"
HEREDOC

cd /var/www/freeinklewriter

bundle install

chown -R www-data:www-data /var/www/freeinklewriter


su www-data -s /bin/bash -c "bin/rails db:migrate RAILS_ENV=production"
su www-data -s /bin/bash -c "rake assets:precompile"

systemctl enable inklewriter
systemctl start inklewriter

