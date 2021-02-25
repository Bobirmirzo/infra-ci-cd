terraform {
  backend "s3" {
    bucket         = "app-infra-state-bucket"
    region         = "ap-northeast-1"
    key            =  "terraform.tfstate"
  }
}