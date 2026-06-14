package main

import (
	"context"
	"encoding/json"
	"log"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ses"
	sestypes "github.com/aws/aws-sdk-go-v2/service/ses/types"
)

type Notification struct {
	Email   string `json:"email"`
	Subject string `json:"subject"`
	Message string `json:"message"`
}

func handler(ctx context.Context, event events.SQSEvent) error {

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return err
	}

	sesClient := ses.NewFromConfig(cfg)

	for _, record := range event.Records {

		log.Printf("Mensaje recibido: %s", record.Body)

		var snsMessage struct {
			Message string `json:"Message"`
		}

		if err := json.Unmarshal([]byte(record.Body), &snsMessage); err != nil {
			log.Printf("Error parseando SNS: %v", err)
			continue
		}

		parts := strings.Split(snsMessage.Message, "|")

		if len(parts) < 3 {
			log.Printf("Formato inválido: %s", snsMessage.Message)
			continue
		}

		notification := Notification{
			Email:   strings.TrimSpace(parts[0]),
			Subject: strings.TrimSpace(parts[1]),
			Message: strings.TrimSpace(parts[2]),
		}

		_, err := sesClient.SendEmail(ctx, &ses.SendEmailInput{

			Source: aws.String("raymond.bautista0208@gmail.com"),

			Destination: &sestypes.Destination{
				ToAddresses: []string{
					notification.Email,
				},
			},

			Message: &sestypes.Message{

				Subject: &sestypes.Content{
					Data: aws.String(notification.Subject),
				},

				Body: &sestypes.Body{
					Text: &sestypes.Content{
						Data: aws.String(notification.Message),
					},
				},
			},
		})

		if err != nil {
			log.Printf("Error enviando correo: %v", err)
			continue
		}

		log.Printf("Correo enviado a %s", notification.Email)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
