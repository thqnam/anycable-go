# syntax=docker/dockerfile:1

FROM golang:1.23-alpine AS build

WORKDIR /src

RUN apk add --no-cache \
    bash \
    bison \
    build-base \
    ca-certificates \
    git \
    ruby

COPY go.mod go.sum ./
COPY vendorlib ./vendorlib

RUN go mod vendor

RUN cd vendorlib/go-mruby && \
    MRUBY_CONFIG=../../etc/build_config.rb make libmruby.a

COPY . .

RUN CGO_ENABLED=1 GOFLAGS="-mod=vendor" go build \
    -tags "mrb gops" \
    -ldflags "-s -w" \
    -o /out/anycable-go ./cmd/anycable-go

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=build /out/anycable-go /usr/local/bin/anycable-go

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/anycable-go"]
