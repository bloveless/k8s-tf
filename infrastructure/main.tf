terraform {
  backend "s3" {
    profile        = "k8s-tf-backend"
    bucket         = "k8s-tf-backend"
    key            = "infrastructure/terraform.tfstate"
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

resource "helm_release" "metallb_system" {
  name             = "metallb-system"
  namespace        = "metallb-system"
  create_namespace = true

  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
}

data "kubectl_path_documents" "metallb" {
  pattern = "./k8s/metallb/*.yaml"
}

resource "kubectl_manifest" "metallb" {
  for_each  = toset(data.kubectl_path_documents.metallb.documents)
  yaml_body = each.value

  depends_on = [helm_release.metallb_system]
}

data "kustomization" "consul_crd" {
  path = "github.com/hashicorp/consul-api-gateway/config/crd?ref=v0.5.1"
}

resource "kustomization_resource" "consul_crd" {
  for_each = data.kustomization.consul_crd.ids

  manifest = data.kustomization.consul_crd.manifests[each.value]
}

resource "helm_release" "consul" {
  name             = "consul"
  namespace        = "consul"
  create_namespace = true
  version          = "1.0.2"

  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"

  values = [
    "${file("./k8s/consul/helm/values.yaml")}"
  ]

  depends_on = [kubectl_manifest.metallb]
}

data "kubectl_path_documents" "consul" {
  pattern = "./k8s/consul/*.yaml"
}

resource "kubectl_manifest" "consul" {
  for_each  = toset(data.kubectl_path_documents.consul.documents)
  yaml_body = each.value

  depends_on = [helm_release.consul]
}
