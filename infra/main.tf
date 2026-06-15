terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.8.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "mongodbatlas" {
  # Requires MONGODB_ATLAS_PUBLIC_KEY and MONGODB_ATLAS_PRIVATE_KEY environment variables
}

variable "mongodb_atlas_org_id" {
  type        = string
  description = "MongoDB Atlas Organization ID"
  default     = "YOUR_ORG_ID"
}

# Azure App Service Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "BooksApiRG"
  location = "East US"
}

# Azure App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = "BooksApiAppServicePlan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Azure Web App for Containers
resource "azurerm_linux_web_app" "webapp" {
  name                = "booksapi-webapp-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan.id

  site_config {
    application_stack {
      docker_image_name   = "booksapi:latest"
      docker_registry_url = "https://index.docker.io/v1/"
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "BookStoreDatabase__ConnectionString" = "mongodb+srv://..."
  }
}

# MongoDB Atlas Project
resource "mongodbatlas_project" "project" {
  name   = "BooksApiProject"
  org_id = var.mongodb_atlas_org_id
}

# MongoDB Atlas Cluster
resource "mongodbatlas_cluster" "cluster" {
  project_id   = mongodbatlas_project.project.id
  name         = "BooksApiCluster"
  cluster_type = "REPLICASET"

  provider_name               = "TENANT"
  backing_provider_name       = "AZURE"
  provider_region_name        = "US_EAST_2"
  provider_instance_size_name = "M0"
}
