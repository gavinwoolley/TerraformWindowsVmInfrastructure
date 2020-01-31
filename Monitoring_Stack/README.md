# Introduction

This folder is to hold all the monitoring tools and scripts.

## Monitoring Stack

The monitoring stack consists of some Docker images and Telegraf.

### Docker Images

* InfluxDb - The Database the holds time series metrics
* Grafana - The Dashboard Frontend
* Portainer - A tool for managing Docker images

## Configuration

These are all created using `docker-compose.yml` file located at `\Monitoring_Stack\Docker`

If you make changes to the `docker-compose` file, the Azure Pipelines workflow `azure-pipeline-docker.yml` will be triggered, once the change is merged.

You can run either `docker-compose-windows.yml` or `docker-compose.yml` on a Linux Docker Host.
The windows docker compose has issues with routing network traffic out. So i went with the Linux Docker for simplicity.

## Telegraf

Telegraf is the Agent used to send metrics from Windows PerfMon or Custom Powershell scripts to the InfluxDb Docker Container.
These are then visualized using Grafana.

Any changes to the telegraf files will trigger the Telegraf pipeline `azure-pipeline-telegraf-agent.yml`

The telegraf pipeline requires an Azure DevOps agent to be running on the target machine.

## InfluxDb Manual Telegraf DB Setup Steps

### Telegraf setup manual steps

* from command prompt on InfluxDb container run
* `influx`
* `create database telegraf`
* `create user telegraf with password 'secret-password'`

## Grafana

Is created using the docker pipeline `azure-pipeline-docker.yml`

You can import this dashboard file `Monitoring_Stack\Grafana\Dashboard.json`

You'll need to create some user accounts and an API token if you want to send graphite annotations of deployments to the graphs.

## Processing Monitor

The Powershell tool for monitoring the Processing also lives in this repository. In the `Processing_Monitor` directory.
Any changes made to this tool, will run the pipeline `azure-pipeline-processing-monitor.yml`
