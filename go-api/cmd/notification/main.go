package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handler(ctx context.Context, event events.SQSEvent) error {

	for _, record := range event.Records {
		log.Printf("Mensaje recibido: %s", record.Body)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
