# azure.ghost-web-app-for-containers

A one-click [Ghost](https://ghost.org/) deployment on [Azure Web App for Containers](https://azure.microsoft.com/en-us/services/app-service/containers/).

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fandrewmatveychuk%2Fazure.ghost-web-app-for-containers%2Fmaster%2Fazuredeploy.json)  [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fandrewmatveychuk%2Fazure.ghost-web-app-for-containers%2Fmaster%2Fazuredeploy.json)

## Getting Started

Basically, this is a multi-container app specified in [a Docker Compose configuration](https://github.com/andrewmatveychuk/azure.ghost-web-app-for-containers/blob/master/docker-compose.yml) and hosted on [Azure Web App for Containers](https://azure.microsoft.com/en-us/services/app-service/containers/). It uses [the custom Ghost Docker image with Azure Application Insights support](https://github.com/andrewmatveychuk/docker-ghost-ai) and [the official MySQL 5.7 Docker image](https://hub.docker.com/_/mysql).

The Azure Web app configuration is provided as a ready-to-use ARM template that deploys and configures all requires Azure resources:

* a Web app and App Hosting plan for running the containers;
* a Log Analytics workspace and Application Insights component for monitoring the application;
* an Azure CDN profile and endpoint for offloading the traffic from the Web app.

All resources have their diagnostic settings configured to stream resource logs and metrics to the Log Analytics workspace.

For the complete list of settings, please refer to the following blog posts:

* [A one-click Ghost deployment on Azure Web App for Containers](https://andrewmatveychuk.com/a-one-click-ghost-deployment-on-azure-web-app-for-containers/)
