# Label selector: e2e
export DEMO_KAFKA_DIR=/home/fjammes/src/github.com/k8s-school/demo-kafka
export DEMO_KAFKA_VERSION=6c7cdd3
export DEMO_KAFKA_WORKBRANCH=main
export CIUX_IMAGE_REGISTRY=
export CIUX_IMAGE_NAME=demo-kafka
# Image which contains latest code source changes DEMO_KAFKA_VERSION
export CIUX_IMAGE_TAG=6c7cdd3
export CIUX_IMAGE_URL=/demo-kafka:6c7cdd3
# True if CIUX_IMAGE_URL need to be built
export CIUX_BUILD=true
# Promoted image is the image which will be push if CI run successfully
export CIUX_PROMOTED_IMAGE_URL=/demo-kafka:6c7cdd3