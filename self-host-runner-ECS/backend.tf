terraform {
  backend "s3" {
    bucket         = "self-host-runner-bucket"
    region         = "ap-northeast-1"
    key            =  "terraform.tfstate"
  }
}