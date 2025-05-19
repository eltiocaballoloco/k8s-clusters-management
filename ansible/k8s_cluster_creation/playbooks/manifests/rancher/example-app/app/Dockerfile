FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod init go-hello-world && go mod tidy
RUN go build -o main .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/main .
RUN chmod +x /app/main

EXPOSE 8080
CMD ["/app/main"]
