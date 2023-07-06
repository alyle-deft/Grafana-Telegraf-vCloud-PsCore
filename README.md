Grafana Telegraf PowerShell Input Script for vCloud Director
===================================

# About

## Project Details
This Repository contains a PowerShell Input Script for Telegraf to collect vCloud Director stats. The generated Data will be used for a [Grafa Dashboard](https://grafana.com/dashboards/5081)*.

# Installation

## Telegraf
Snippet of the telegraf.conf input:
```
[[inputs.exec]]
  commands = ["pwsh /scripts/Grafana-Telegraf-vCloud-PsCore/vCloud.ps1"]
  name_override = "vCloudStats"
  interval = "60s"
  timeout = "60s"
  data_format = "influx"
```

## Grafana
Updating dashboard to work with Grafana v10 is a work in progress

# Screenshots


*W.I.P
