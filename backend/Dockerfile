FROM golang:1.22-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dashboard-api ./cmd/dashboard-api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/dashboard-api /dashboard-api
EXPOSE 8080
ENTRYPOINT ["/dashboard-api"]
