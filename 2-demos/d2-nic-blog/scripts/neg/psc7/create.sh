
gcloud beta compute network-endpoint-groups create ${NEG_NAME} \
--project=${PROJECT_ID} \
--network=${NETWORK} \
--region=${REGION} \
--network-endpoint-type=PRIVATE_SERVICE_CONNECT \
--psc-target-service="${TARGET_SERVICE}"
