#!/usr/bin/env bash

echo "Current OPM version is: $(opm version)"
echo "Requires OPM v1.29.0+"

opm alpha render-template basic components/4.13.yaml > v4.13/catalog/kubevirt-hyperconverged/catalog.yaml
