# syntax=docker/dockerfile:1

FROM ruby:2.7-alpine AS build

WORKDIR /src

RUN apk add --no-cache \
    bash \
    bison \
    build-base \
    ca-certificates \
    git \
    go \
    musl-dev

COPY go.mod go.sum ./
COPY vendorlib ./vendorlib
COPY etc ./etc

RUN go mod vendor

COPY . .

RUN gem install getoptlong --no-document

RUN cd vendorlib/go-mruby && \
    MRUBY_CONFIG=/src/etc/build_config.rb make libmruby.a

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
