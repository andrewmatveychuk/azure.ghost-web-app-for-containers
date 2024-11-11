# azure.ghost-web-app-for-containers

A one-click [Ghost](https://ghost.org/) deployment on [Azure Web App for Containers](https://azure.microsoft.com/en-us/services/app-service/containers/).

## Deploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fandrewmatveychuk%2Fazure.ghost-web-app-for-containers%2Fmaster%2Fghost.json)

## Getting Started

This is an Azure Web app deployed as a container . It uses [the custom Ghost Docker image with Azure Application Insights support](https://github.com/andrewmatveychuk/docker-ghost-ai) and [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) to store the application data.

The Azure Web app configuration is provided as a ready-to-use Bicep template that deploys and configures all required Azure resources:

* a VNet for private endpoints and internal app communication;
* a Web app for running the container;
* a Key Vault for storing secrets such as database passwords;
* a Log Analytics workspace and Application Insights component for monitoring the application;
* an Azure Database for MySQL server;
* an (optional) Front Door profile to secure and offload the traffic from the Web app .

All resources have their diagnostic settings configured to stream resource logs and metrics to the Log Analytics workspace.

For the complete list of settings, please refer to the following blog posts:

* [How to connect to Azure Database for MySQL from Ghost container](https://andrewmatveychuk.com/how-to-connect-to-azure-database-for-mysql-from-ghost-container/)
* [Ghost deployment on Azure: Security Hardening](https://andrewmatveychuk.com/ghost-deployment-on-azure-security-hardening/)
* [A one-click Ghost deployment on Azure Web App for Containers](https://andrewmatveychuk.com/a-one-click-ghost-deployment-on-azure-web-app-for-containers/)
