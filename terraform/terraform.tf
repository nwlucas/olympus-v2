terraform {
  experiments = [module_variable_optional_attrs]
  backend "s3" {
    bucket         = "olympus-net-remote-state-storage"
    key            = "olympus-v2"
    region         = "us-east-1"
    dynamodb_table = "olympus-net-v2"
  }
}
