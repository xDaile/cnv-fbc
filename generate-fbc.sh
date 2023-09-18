#!/usr/bin/env bash

set -e

package_name="kubevirt-hyperconverged"

helpFunction()
{
   echo -e "Usage: $0\n"
   echo -e "\t--help :   see all commands of this script\n"
   echo -e "\t--init-basic :   initialize a new composite fragment\n\t  example: $0 --init-basic v4.13 yq\n"
   echo -e "\t--render : render one FBC fragment\n\t  example: $0 --render v4.13\n"
   exit 1
}

devfile()
{
    cat <<EOT > $1/devfile.yaml 
schemaVersion: 2.2.0
metadata:
  name: fbc-$1
  displayName: FBC $1
  description: 'File based catalog'
  language: fbc
  provider: Red Hat
components:
  - name: image-build
    image:
      imageName: ""
      dockerfile:
        uri: $1/catalog.Dockerfile
        buildContext: ""
  - name: kubernetes
    kubernetes:
      inlined: placeholder
    attributes:
      deployment/container-port: 50051
      deployment/cpuRequest: "100m"
      deployment/memoryRequest: 512Mi
      deployment/replicas: 1
      deployment/storageRequest: "0"
commands:
  - id: build-image
    apply:
      component: image-build
EOT
}

dockerfile()
{
    cat <<EOT > $1/catalog.Dockerfile
# The base image is expected to contain
# /bin/opm (with a serve subcommand) and /bin/grpc_health_probe
FROM registry.redhat.io/openshift4/ose-operator-registry:$1

# Configure the entrypoint and command
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]

# Copy declarative config root into image at /configs and pre-populate serve cache
ADD catalog /configs
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

# Set DC-specific label for the location of the DC root directory
# in the image
LABEL operators.operatorframework.io.index.configs.v1=/configs
EOT
}

cmd="$1"
case $cmd in
    "--help")
        helpFunction
    ;;
     "--init-basic")
        frag=$2
        from=registry.redhat.io/redhat/redhat-operator-index:$frag
        yqOrjq=$3
        mkdir -p "${frag}/catalog/kubevirt-hyperconverged/" "${frag}/${frag}"
	touch "${frag}/${frag}/.empty"
        case $yqOrjq in
            "yq")
                touch ${frag}/graph.yaml
                opm render $from -o yaml | yq "select( .package == \"$package_name\" or .name == \"$package_name\")" | yq 'select(.schema == "olm.bundle") = {"schema": .schema, "image": .image}' | yq 'select(.schema == "olm.package") = {"schema": .schema, "name": .name, "defaultChannel": .defaultChannel}' >> ${frag}/graph.yaml
            ;;
            "jq")
                opm render $from | jq "select( .package == \"$package_name\" or .name == \"$package_name\")" | jq 'if (.schema == "olm.bundle") then {schema: .schema, image: .image} else (if (.schema == "olm.package") then {schema: .schema, name: .name, defaultChannel: .defaultChannel} else . end) end' >> ${frag}/graph.json
            ;;
            *)
                echo "please specify if yq or jq"
                exit 1
            ;;
        esac
        devfile $frag
	dockerfile $frag
    ;;
    "--render")
	frag=$2
        opm alpha render-template basic ${frag}/graph.yaml > ${frag}/catalog/kubevirt-hyperconverged/catalog.yaml
    ;;
    *)
        echo "$cmd not one of the allowed flags"
        helpFunction
    ;;
esac
