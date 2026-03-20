# Start from the official Go image
FROM golang:1.22.4-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod tidy
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/main.go

# Final stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates curl

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.0.3.tgz \
    | tar xz --strip-components=1 -C /usr/local/bin docker/docker

WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
