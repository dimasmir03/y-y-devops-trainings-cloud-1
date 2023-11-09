# Start by building the application.
FROM golang:1.21 as build

WORKDIR /go/src/catgpt

COPY . .

RUN go mod download
RUN go vet -v
RUN go test -v
RUN CGO_ENABLED=0 go build -o /go/bin/catgpt

# Now copy it into our base image.
FROM gcr.io/distroless/static-debian12:latest-amd64
COPY --from=build /go/bin/catgpt /
CMD ["/catgpt"]