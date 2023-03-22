#!/usr/bin/env bash

echo "Current OPM version is: $(opm version)"
echo "Requires OPM v1.26.3+"

if [ -z "$1" ]; then
  echo "usage: <script> <step #>"
  exit 1
fi

opm alpha render-veneer basic components/v4.13-${1}.yaml > v4.13/catalog/kubevirt-hyperconverged/catalog.yaml
