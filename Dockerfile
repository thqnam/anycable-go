# syntax=docker/dockerfile:1

FROM ruby:2.7-alpine AS mruby-build

WORKDIR /src

RUN apk add --no-cache \
    bash \
    bison \
    build-base \
    ca-certificates \
    git \
    musl-dev

COPY go.mod go.sum ./
COPY vendorlib ./vendorlib
COPY etc ./etc

RUN gem install getoptlong --no-document

RUN cd vendorlib/go-mruby && \
    MRUBY_CONFIG=/src/etc/build_config.rb make libmruby.a

FROM golang:1.23-alpine AS build

WORKDIR /src

RUN apk add --no-cache \
    bash \
    build-base \
    ca-certificates \
    git

COPY go.mod go.sum ./
COPY vendorlib ./vendorlib
COPY etc ./etc
COPY . .

RUN go mod download
COPY --from=mruby-build /src/vendorlib/go-mruby/libmruby.a /src/vendorlib/go-mruby/libmruby.a
COPY --from=mruby-build /src/vendorlib/go-mruby/mruby-build /src/vendorlib/go-mruby/mruby-build

RUN CGO_ENABLED=1 go build \
    -tags "mrb gops" \
    -ldflags "-s -w" \
    -o /out/anycable-go ./cmd/anycable-go

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=build /out/anycable-go /usr/local/bin/anycable-go

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/anycable-go"]
