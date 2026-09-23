# Azure Global 2026 Krakow Workshop
Materials for workshop that happend 16.04.2026 in Krakow under Global Azure 2026 by [Dominik Skowron](https://www.linkedin.com/in/dominikskowron007/) & [Damian Maczuga](https://www.linkedin.com/in/damianmaczuga/) & [Paweł Chylak](https://www.linkedin.com/in/pawel-chylak/)

![logo](./logo.png)
Participants learned how to set up a fully automated, secure CI/CD pipeline for deploying a web application to Azure using **GitHub Actions** and **passwordless authentication via Federated Identity**.

## Key Topics Covered
- Creating and configuring a GitHub repository
- Setting up Azure resources:
  - User Assigned Managed Identity
  - Azure Blob Storage for Terraform state
  - Azure Container Registry (ACR)
  - Terraform Modules
- Configuring GitHub Secrets for secure integration
- Writing and deploying:
  - `main.tf` (Terraform configuration)
  - GitHub Actions workflow (`deploy.yml`)
- **Passwordless authentication using OIDC federation** between GitHub and Azure
- Secure infrastructure and app deployment using Infrastructure as Code (IaC)

This workshop showcased best practices for modern DevOps workflows with **Terraform Modules**, **containerization**, and **secure CI/CD pipelines** on Azure

# Instruction
## 1. Create Free GitHub Account
    - Write down your user name
    - Create empty repo with README.md file
    - write down repo name

## 2. Log into Azure Account
    - Find your Resource Group

## 3. Managed Identity
    - Create User Assigned Managed Identity (in your Resource Group)
    - <your-managed-Identity> -> Settings -> Federated credentials -> Add Credential:
        - Federated credential scenario = GitHub Actions deploying...
        - Organization = YOUR GH USERNAME
        - Repository = YOUR GH REPO NAME
        - Entity = Branch
        - Branch = main
        - Name credentials-name
        
    - Go to your Resource Group -> Access control (IAM) -> Add role assignment -> Privileged administrator roles -> Contributor -> Managed identity -> Your MI.

## 4. Create Blob
    - Create Azure Storage Account (for tfstate)
    - In Azure Storage Account create blob named tfstate
    - In Your Storage Account -> Access Control (IAM) -> Add+ -> Add role assignment -> Storage Blob Data Contributor -> Managed Idenity (+Select Member) -> your managed idenity

## 5. ACR
    - in your RG create "Container registries"
    - provide name, rest default -> create
    - In ACR check in Admin User
    - In Your ACR -> Access Control (IAM) -> Add+ -> Add role assignment -> AcrPush -> Managed Idenity (+Select Member) -> your managed idenity

## 6. GH Secrets
    - go to your GH Repo
    - Settings
    - Security / secrets and variables / actions
    - new repository Secret (and create with name:value)
        - ACR_LOGIN_SERVER (from your ACR overview)
        - AZURE_CLIENT_ID (from your MI overview)
        - AZURE_SUBSCRIPTION_ID (from your MI overview)
        - AZURE_TENANT_ID (from your MI Settings -> Properties)

## 7. Let's Code!
- create files:
    - main.tf
    - .github/workflows/deploy.yml

## main.tf
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "example-resources" #change here
    storage_account_name = "tfstorage123dominik" #change here
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

```
## .github/workflows/deploy.yml
```yml
name: CI/CD Pipeline

permissions:
  id-token: write
  contents: read

on:
  push:
    branches:
      - main
  
jobs:
  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: 'Azure login'
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}  

      - name: Login to Azure Container Registry
        run: az acr login --name ${{ secrets.ACR_LOGIN_SERVER }}

      - name: Build Docker Image
        run: |
          docker build -t ${{ secrets.ACR_LOGIN_SERVER }}/example-webapp:latest .

      - name: Push Docker Image to ACR
        run: |
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/example-webapp:latest

  deploy-infra:
    name: Deploy Infrastructure
    runs-on: ubuntu-latest
    needs: build-and-push

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: set-variables
        shell: 'pwsh'
        run: |
          @("ARM_CLIENT_ID=${{ secrets.AZURE_CLIENT_ID }}",
            "ARM_SUBSCRIPTION_ID=${{ secrets.AZURE_SUBSCRIPTION_ID }}",
            "ARM_TENANT_ID=${{ secrets.AZURE_TENANT_ID }}",
            "ARM_USE_OIDC=true",
            "ARM_USE_AZUREAD=true") | Out-File -FilePath $env:GITHUB_ENV -Append

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Initialize Terraform
        shell: 'pwsh'
        run: terraform init

      - name: Plan Terraform Changes
        shell: 'pwsh'
        run: terraform plan

      - name: Apply Terraform Changes
        shell: 'pwsh'
        run: terraform apply -auto-approve

  update-app-service:
    name: Update App Service with Latest Image
    runs-on: ubuntu-latest
    needs: deploy-infra

    steps:
      - name: 'Azure login'
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        
      - name: Update App Service
        run: |
          az webapp config container set \
            --name example-webapp-123123i95u8fhwfdsewdwsa \
            --resource-group example-resources \
            --docker-custom-image-name ${{ secrets.ACR_LOGIN_SERVER }}/example-webapp:latest \
            --docker-registry-server-url https://${{ secrets.ACR_LOGIN_SERVER }}
```

# Linki
https://dev.azure.com/globalazure2026krk/

https://portal.azure.com/

https://github.com/pchylak/global_azure_2026_ccoe


# Nagrody

Każdy kto wykona wszystkie zadania bierze udział w losowaniu nagrody główniej.
Pierwsze X osób które wykonają najszybciej zadania wybierają nagrody z sejfu

# Zadania

- Wstęp Teoretyczny
- Architecture Overview
<img width="800" height="533" alt="image" src="https://github.com/user-attachments/assets/4d2f6f47-54af-4271-9b06-ad5a36924a68" />

- Zaloguj się do Azure portal
    - znajdź swoją resource group
- Zaimportuj twoją resource group (userX) do terraform (1 pkt)
- Zrób Connection dla twojej resource groupy (pomiędzy GitHub a Azurem) (1 pkt)
- Stwórz GitHub Action pod deployment Terraforma (Terraform INIT + PLAN + APPLY) (1 pkt)
    - możesz wykorzystać TerraformTaskV4@4
    - skonfiguruj backend/config dla terraforma
- Zrób Deploy zasobów zgodnie z architekturą:
    - skorzystaj z modułów https://github.com/pchylak/global_azure_2026_ccoe
    - instrukcja skorzystania z modułów jest w sekji wiki
    - zasoby do powołania:
        - Managed Identity (1 pkt)
        - Key Vault (1 pkt)
        - MS SQL (1 pkt)
        - Application Insights (1 pkt)
        - App Service Plan (b1) (1 pkt)
        - Azure App Service (1 pkt)
        - Azure Container Registry (1 pkt)
- Zamontuj Pipeline pod deployment aplikacji
    - Docker Build (1 pkt)
    - Docker Push to ACR (Azure Container Registry) (1 pkt)
- Rozszerz pipeline o deploy na powołany Azure App Service (1 pkt)
    - możesz użyć do tego AzureWebAppContainer@1
- Uzupełnij zmienne środowiskowe dla aplikacji aby wyświetlała pełnie funkcjonalności (1 pkt)
    - ENV za pomocą terraform
    - pamiętaj, że jeżeli zmienna jest sekretem możesz wykorzystać Key Vault

# Wskazówki
- pamiętaj, że Managed Idenitiy z którego będzie korzystała twoja aplikacja musi być do niej przypisane i posiadać odpowiednie role do "komunikacji" z SQL, KV etc
- sekrety przechowuj w KeyVault
- ręczne klikanie w portal Azure = tylko do weryfikacji / debug
- infrastruktura powinna być odtwarzalna z kodu
