#!/bin/bash

docker run -p 8080:80 \
           -it \
           --rm \
           --name pgadmin \
           -e PGADMIN_DEFAULT_EMAIL=admin@pg.com \
           -e PGADMIN_DEFAULT_PASSWORD=admin \
           dpage/pgadmin4:9.2.0
