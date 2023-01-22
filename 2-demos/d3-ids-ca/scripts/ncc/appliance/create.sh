#!/bin/bash

# spoke

gcloud alpha network-connectivity spokes create ${SPOKE_NAME} \
--project=${PROJECT_ID} \
--hub=${HUB_NAME} \
--description=${SPOKE_NAME} \
--router-appliance=instance=${APPLIANCE_SELF_LINK},ip=${APPLIANCE_IP} \
--region=${REGION}

# interfaces

gcloud alpha compute routers add-interface ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--interface-name=${APPLIANCE_NAME}-0  \
--subnetwork=${SUBNET} \
--region=${REGION} \
--ip-address=${SPOKE_CR_IP_0}

gcloud alpha compute routers add-interface ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--interface-name=${APPLIANCE_NAME}-1  \
--redundant-interface=${APPLIANCE_NAME}-0 \
--subnetwork=${SUBNET} \
--region=${REGION} \
--ip-address=${SPOKE_CR_IP_1}

# bgp

gcloud alpha compute routers add-bgp-peer ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--peer-name=${APPLIANCE_NAME}-0 \
--interface=${APPLIANCE_NAME}-0 \
--peer-ip-address=${APPLIANCE_IP} \
--peer-asn=${APPLIANCE_ASN} \
--instance=${APPLIANCE_NAME} \
--region=${REGION} \
--instance-zone=${APPLIANCE_ZONE} \
--advertisement-mode=CUSTOM \
--advertised-route-priority=${APPLIANCE_SESSION_0_METRIC} \
--set-advertisement-ranges=${APPLIANCE_ADVERTISED_PREFIXES}


gcloud alpha compute routers add-bgp-peer ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--peer-name=${APPLIANCE_NAME}-1 \
--interface=${APPLIANCE_NAME}-1 \
--peer-ip-address=${APPLIANCE_IP} \
--peer-asn=${APPLIANCE_ASN} \
--instance=${APPLIANCE_NAME} \
--region=${REGION} \
--instance-zone=${APPLIANCE_ZONE} \
--advertisement-mode=CUSTOM \
--advertised-route-priority=${APPLIANCE_SESSION_0_METRIC} \
--set-advertisement-ranges=${APPLIANCE_ADVERTISED_PREFIXES}
