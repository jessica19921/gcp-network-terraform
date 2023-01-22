
PORT=${CONTAINER_PORT}
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud builds submit --tag ${IMAGE_REPO} ${DOCKERFILE_DIR}
gcloud config unset project
