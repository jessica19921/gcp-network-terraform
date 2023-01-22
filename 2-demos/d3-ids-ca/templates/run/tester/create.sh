
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
docker build -t ${IMAGE_REPO} ${DOCKERFILE_DIR}
docker push ${IMAGE_REPO}
gcloud container images list --repository=${GCR_HOST}/${PROJECT}
