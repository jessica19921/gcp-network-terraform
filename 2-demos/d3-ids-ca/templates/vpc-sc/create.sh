#!/bin/bash

# policy
#------------------------------------

gcloud access-context-manager policies create \
--organization ${ORGANIZATION_ID} \
--title ${POLICY_TITLE}
echo ""

POLICY_NAME=$(gcloud access-context-manager policies list \
--organization ${ORGANIZATION_ID} \
--format="value(name)")
echo ""

gcloud config set access_context_manager/policy $POLICY_NAME

# access levels
#------------------------------------

%{~ for k,v in ACCESS_LEVELS.ip ~}
gcloud access-context-manager levels create ${k} \
--title=allow-public-ip \
--basic-level-spec=<(echo '
- ipSubnetworks:
%{ for prefix in v ~}
  - ${prefix}
%{ endfor ~}
')
echo ""
%{ endfor ~}

%{ for k,v in PERIMETERS ~}
# perimeter - ${k}
#------------------------------------

gcloud beta access-context-manager perimeters create ${k} \
--title=${k} \
--perimeter-type=${v.type} \
--resources=projects/${v.project_number} \
--restricted-services=${v.restricted_services} \
--vpc-allowed-services=RESTRICTED-SERVICES \
--enable-vpc-accessible-services
echo ""

# egress

%{ if length(v.egress) != 0 ~}
gcloud beta access-context-manager perimeters update ${k} \
--set-egress-policies=<(echo '
%{ for rule in v.egress ~}
- egressFrom:
    identities:
    - serviceAccount:${rule.from.identity}
  egressTo:
    operations:
    - serviceName: ${rule.to.service}
      methodSelectors:
      - method: ${rule.to.method}
    resources:
    - projects/${rule.to.project}
%{ endfor ~}
')
echo ""
%{ endif ~}

# ingress

%{~ if length(v.ingress) != 0 ~}

gcloud beta access-context-manager perimeters update ${k} \
--set-ingress-policies=<(echo '
%{ for rule in v.ingress ~}
- ingressFrom:
    identities:
    - serviceAccount:${rule.from.identity}
%{ if rule.from.project != null ~}
    sources:
    - resource: projects/${rule.from.project}
%{ endif ~}
  ingressTo:
    operations:
    - serviceName: ${rule.to.service}
      methodSelectors:
      - method: ${rule.to.method}
    resources:
    - projects/${rule.to.project}
%{ endfor ~}
')
echo ""
%{ endif ~}
%{ endfor ~}
