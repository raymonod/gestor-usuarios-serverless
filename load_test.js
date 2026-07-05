import http from 'k6/http';

export const options = {
  vus: 500,
  duration: '5m',
};

export default function () {

  const payload = JSON.stringify({
    email: 'raymond.bautista0208@gmail.com',
    subject: 'Prueba',
    message: 'Mensaje de carga'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6InJheW1vbmRAZ21haWwuY29tIiwiZXhwIjoxNzgxNTQwNjM1LCJpYXQiOjE3ODE0NTQyMzV9.dYpaZasFOH3MuhFzuAlRlgCRbhAe_OqJ2icod9cZ524'
    }
  };

  http.post(
    'https://mgfvk88j53.execute-api.us-east-1.amazonaws.com/notifications/send',
    payload,
    params
  );
}