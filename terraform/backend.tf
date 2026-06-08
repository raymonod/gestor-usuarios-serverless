terraform {
  backend "s3" {
    bucket = "gestor-usuarios"
    key    = "gestor-usuarios/terraform.tfstate"
    region = "us-east-2"
  }
}