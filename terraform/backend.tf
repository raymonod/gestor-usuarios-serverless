terraform {
  backend "s3" {
    bucket = "gestor-usuarios/gestor-usuarios"
    key    = "gestor-usuarios/terraform.tfstate"
    region = "us-east-2"
  }
}