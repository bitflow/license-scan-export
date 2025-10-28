FROM alpine:edge AS base

ENV DOCKER=1

RUN apk upgrade
RUN apk add --no-cache bash tree zip
COPY . /app
WORKDIR /code
# RUN pwd; ls -l
ENTRYPOINT ["/app/export.sh"]
