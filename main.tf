terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.1.0"
    }
  }
}
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "AzureGlobal"
    storage_account_name = "tfstateblobstorage001"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

module "keyvault" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=keyvault/v1.0.0"
  keyvault_name = "gakvuser182026"
  resource_group = {
    location = var.location
    name     = var.resource_group
  }
  network_acls = {
    bypass = "AzureServices"
  }

}


module "mssql_server" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=mssql_server/v1.0.0"
  
  resource_group = { 
    location = var.location
    name     = var.resource_group
  }

  sql_server_admin = "ibrahim"

  sql_server_name = "example-webapp-sql-server"

  sql_server_version = "12.0"

}

module "application_insights" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=application_insights/v1.0.0"
  # also any inputs for the module (see below)
  application_insights_name = "example-webapp-ai"
  log_analytics_name = "example-webapp-la"
  resource_group = {
    location = var.location
    name     = var.resource_group
  }
}

module "managed_identity" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=managed_identity/v1.0.0"
  # also any inputs for the module (see below)
  name = "example-webapp-mi"
  resource_group = {
    location = var.location
    name     = var.resource_group
  }

  permissions = [
    {
      scope = "/subscriptions/8c019dba-0d3c-4974-b897-c01b236aeb6e/resourceGroups/AzureGlobal/providers/Microsoft.ContainerRegistry/registries/azureglobal"
      role_name = "AcrPull"
    }
  ]
}

module "service_plan" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=service_plan/v2.0.0"
  app_service_plan_name = "example-webapp-sp"
  resource_group = {
    location = var.location
    name     = var.resource_group 
  }
  sku_name = "F1"
  tags = {
    environment = "dev"
  }
}

module "app_service" {
  source = "git::https://github.com/pchylak/global_azure_2026_ccoe.git?ref=app_service/v1.0.0"
  app_service_name = "example-webapp-56456345645"
  app_service_plan_id = module.service_plan.app_service_plan_id
  app_settings = {
    "ApplicationInsights__ConnectionString" = module.application_insights.app_insights_connection_string
    "WEBSITES_PORT" = "8080"
    "DOCKER_REGISTRY_SERVER_URL" = "https://azureglobal.azurecr.io"
  }
  identity_client_id = module.managed_identity.managed_identity_client_id
  identity_id = module.managed_identity.managed_identity_id
  resource_group = {
    location = var.location
    name     = var.resource_group
  }
  always_on = false
}