#!/bin/bash

POLICY_NAME=$(gcloud access-context-manager policies list \
--organization ${ORGANIZATION_ID} \
--format="value(name)")

%{~ for k,v in PERIMETERS ~}
gcloud -q access-context-manager perimeters delete ${k} && echo ""
%{ endfor ~}
%{~ for k,v in ACCESS_LEVELS.ip ~}
gcloud -q access-context-manager levels delete ${k} && echo ""
%{ endfor ~}
gcloud -q access-context-manager policies delete $POLICY_NAME && echo ""
