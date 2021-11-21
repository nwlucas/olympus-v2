provider "aws" {
  region = "us-east-1"
}

provider "cloudflare" {

}

provider "dns" {

}

provider "tls" {

}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
