# azure.ghost-web-app-for-containers

A one-click [Ghost](https://ghost.org/) deployment on Azure with options to deploy it to:

* [Azure Web App for Containers](https://azure.microsoft.com/en-us/services/app-service/containers/)
* [Azure Container Apps](https://azure.microsoft.com/en-us/products/container-apps/)

## Disclaimer

Please note that both deployment options might not be the best option cost-wise to run a small personal blog on Ghost in Azure.
The goal of those deployment templates is to showcase how you can automate the process of setting up a containerized application with various infrastructure dependencies in Azure.

## Getting Started

This is a Ghost blogging platform deployed as a container on Azure services. By default, it uses [a custom Ghost Docker image with Azure Application Insights support](https://github.com/andrewmatveychuk/docker-ghost-ai), which you can easily replace with [the Ghost container official image](https://hub.docker.com/_/ghost/) via the template parameters.

It also leverages [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) to store the application data.

The deployment configuration is provided as ready-to-use Bicep templates that deploy and configure all required Azure resources:

* a VNet for private endpoints and internal app communication;
* a Web App or Container App for running the Ghost container;
* a Key Vault for storing secrets such as database passwords;
* a Log Analytics workspace and Application Insights component for monitoring the application;
* an Azure Database for MySQL Flexible Server;
* an (optional) Front Door profile to secure and offload the traffic from the app.

All resources have their diagnostic settings configured to stream resource logs and metrics to the Log Analytics workspace.

For the complete list of settings, please refer to the following blog posts:

* [Ghost on Azure: Project Update. New Ghost 5 image, Azure MySQL Flexible Server, Azure Private Link, RBAC for Key Vault, and App Service access restrictions to Azure Front Door](https://andrewmatveychuk.com/ghost-on-azure-project-update/)
* [How to connect to Azure Database for MySQL from Ghost container](https://andrewmatveychuk.com/how-to-connect-to-azure-database-for-mysql-from-ghost-container/)
* [Ghost deployment on Azure: Security Hardening](https://andrewmatveychuk.com/ghost-deployment-on-azure-security-hardening/)
* [A one-click Ghost deployment on Azure Web App for Containers](https://andrewmatveychuk.com/a-one-click-ghost-deployment-on-azure-web-app-for-containers/)

## Deploy to Azure Web App for Containers

You can deploy it as a Web App with public access or a Web App fronted by an Azure Front Door Standard profile. If deployed with the Azure Front Door Standard profile, the Web App is configured with [access restrictions](https://learn.microsoft.com/en-us/azure/app-service/overview-access-restrictions) allowing traffic from the Front Door profile only.

[![Deploy to Azure Web App for Containers](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fandrewmatveychuk%2Fazure.ghost-web-app-for-containers%2Fmaster%2Fghost-as-webapp.json)

*Post-deployment steps: none.*

Check for the `endpointHostName` deployment output value for the app URL. Depending on the deployment configuration (Web App with public access or with Azure Front Door), it will point to the Web App or to the Front Door profile public endpoint.

It takes some time for the Ghost container to be pulled/started and the application to be initialized, so check the container deployment logs on the Web App for container status.

## Deploy to Azure Container Apps

You can deploy it as a Container App with public access in a Container App Environment with public ingress enabled or a Container App in a locked-down [Container App Environment accessible only via the Azure Front Door (Premium) private link](https://learn.microsoft.com/en-us/azure/container-apps/how-to-integrate-with-azure-front-door). If deployed with the Azure Front Door private link, the Container App endpoint is inaccessible from the public network, which is good practice for production deployments.

[![Deploy to Azure Container Apps](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fandrewmatveychuk%2Fazure.ghost-web-app-for-containers%2Fmaster%2Fghost-as-containerapp.json)

*Post-deployment steps:*

1) [Approve the private endpoint connection request from the Azure Front Door profile on your Container App Environment](https://learn.microsoft.com/en-us/azure/container-apps/how-to-integrate-with-azure-front-door?pivots=azure-portal#approve-the-private-endpoint-connection-request). This step cannot be automated, as you essentially need to approve a connection via Private Link from the Front Door externally managed environment.
2) Check and copy the `endpointHostName` deployment output value for the app URL. Depending on the deployment configuration (Container App with public access or with Azure Front Door), it will point to the Container App or to the Front Door profile public endpoint.
3) Update the `url` [environment variable in the container properties](https://learn.microsoft.com/en-us/azure/container-apps/environment-variables) with the `endpointHostName` output value. Ghost needs that variable to point to the website FQDN to work correctly. Updating a container (app) variable creates a new app revision.

It takes some time for the Ghost container to be pulled/started and the application to be initialized, so check the container deployment logs on the Container App for container status.
