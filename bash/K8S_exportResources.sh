#!/bin/bash
# This script exports resource details form a kubernetes cluster
# Requires cluster-admin privileges

MYBACKUPDIR=/tmp/k8sinfo-$(date +%Y%m%d%H%M)
mkdir -p ${MYBACKUPDIR}

kubectl get nodes -o wide > ${MYBACKUPDIR}/00_cluster_nodes.out
kubectl cluster-info > ${MYBACKUPDIR}/00_cluster_info.out
kubectl api-resources > ${MYBACKUPDIR}/00_cluster_api.out

for OBJECT in namespaces nodes pv crd psp clusterroles clusterrolebindings pc sc; do
  FILE=${MYBACKUPDIR}/01_k8s-${OBJECT}.yaml
  echo "#**************** SUMMARY ************************" > ${FILE}
  kubectl get ${OBJECT} -o wide | awk '{print "# "$0}' >> ${FILE}
  echo "#***************** YAML **************************" >> ${FILE}
  kubectl get ${OBJECT} -o wide -o yaml 2>&- >> ${FILE}
done

NAMESPACES=($(kubectl get ns -o name | awk '{split($0,a,"/"); print a[2]}'))
for INDEX in ${!NAMESPACES[*]}; do
  NAMESPACE=${NAMESPACES[$INDEX]}
  NAMESPACEDIR=${MYBACKUPDIR}/ns-${NAMESPACE}
  echo "$(date) --------------------------> Working on: $NAMESPACE"
  mkdir -p ${NAMESPACEDIR}
  for OBJECT in cm limitranges pvc pods rc rs quota sa svc ds deploy sts hpa cj jobs ing netpol pdb rolebindings roles; do
    FILE=${NAMESPACEDIR}/${NAMESPACE}-${OBJECT}.yaml
    echo "#**************** SUMMARY ************************" > ${FILE}
    kubectl get ${OBJECT} -o wide -n ${NAMESPACE} | awk '{print "# "$0}' >> ${FILE}
    echo "#***************** YAML **************************" >> ${FILE}
    kubectl get ${OBJECT} -o wide -o yaml -n ${NAMESPACE} 2>&- >> ${FILE}
  done
done

