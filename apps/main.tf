terraform {
  backend "s3" {
    profile        = "k8s-tf-backend"
    bucket         = "k8s-tf-backend"
    key            = "apps/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "k8s-tf-backend"
  }

  required_providers {
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kustomization" {
  kubeconfig_path = "~/.kube/config"
}

data "kubectl_path_documents" "two_services" {
  pattern = "./k8s/two-services/*.yaml"
}

resource "kubectl_manifest" "two_services" {
  for_each  = toset(data.kubectl_path_documents.two_services.documents)
  yaml_body = each.value
}
