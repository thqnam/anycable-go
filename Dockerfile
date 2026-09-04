# syntax=docker/dockerfile:1

# ==========================================
# Stage 1: Build mruby C library
# ==========================================
FROM ruby:3.3-alpine AS mruby-build

WORKDIR /src

# Cài đặt công cụ biên dịch và gem trước để cache vĩnh viễn
RUN apk add --no-cache \
    bash \
    bison \
    build-base \
    ca-certificates \
    git \
    musl-dev && \
    gem install getoptlong --no-document

# Chỉ copy đúng những file cần thiết cho mruby (KHÔNG copy go.mod/go.sum vào đây)
COPY vendorlib/go-mruby ./vendorlib/go-mruby
COPY etc/build_config.rb ./etc/build_config.rb

RUN cd vendorlib/go-mruby && \
    MRUBY_CONFIG=/src/etc/build_config.rb make libmruby.a

# ==========================================
# Stage 2: Build Go binary
# ==========================================
FROM golang:1.23-alpine AS build

WORKDIR /src

RUN apk add --no-cache \
    bash \
    build-base \
    ca-certificates \
    git

# 1. Chỉ copy file định nghĩa module và thư mục vendorlib (được khai báo trong go.mod replace)
COPY go.mod go.sum ./
COPY vendorlib/go-mruby ./vendorlib/go-mruby

# 2. Tải Go modules trước và sử dụng BuildKit cache mount
# Layer này sẽ được CACHE TUYỆT ĐỐI trừ khi bạn thực sự thay đổi go.mod
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# 3. Sau khi đã cache dependencies, mới copy toàn bộ mã nguồn còn lại
COPY . .

# 4. Copy artifact libmruby đã build từ Stage 1
COPY --from=mruby-build /src/vendorlib/go-mruby/libmruby.a /src/vendorlib/go-mruby/libmruby.a
COPY --from=mruby-build /src/vendorlib/go-mruby/mruby-build /src/vendorlib/go-mruby/mruby-build

# 5. Biên dịch Go với cache mount cho cả module và compiler cache
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 go build \
    -tags "mrb gops" \
    -ldflags "-s -w" \
    -o /out/anycable-go ./cmd/anycable-go

# ==========================================
# Stage 3: Minimal & Secure Runtime
# ==========================================
FROM alpine:3.20

# Cài đặt chứng chỉ SSL và múi giờ
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copy binary từ build stage
COPY --from=build /out/anycable-go /usr/local/bin/anycable-go

# Chạy với user không đặc quyền (nobody) để đảm bảo an toàn
USER nobody

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/anycable-go"]