#!/bin/bash
# This script exports resource details form a kubernetes cluster
# Requires cluster-admin privileges

MYBACKUPDIR=/tmp/k8sinfo-$(date +%Y%m%d%H%M)
TARFILE=/tmp/k8sinfo-$(date +%Y%m%d%H%M).tar.gz

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

##########################################################################

mkdir -p ${MYBACKUPDIR}
CRD_CLUSTER=$(kubectl get crd -o jsonpath='{range .items[?(@.spec.scope=="Cluster")]}{.metadata.name}{" "}{end}')
CRD_NAMESPACED=$(kubectl get crd -o jsonpath='{range .items[?(@.spec.scope=="Namespaced")]}{.metadata.name}{" "}{end}')

printf "\n$(date) -> ${green}Exporting High Level Cluster Information${reset}\n"
kubectl get nodes -o wide > ${MYBACKUPDIR}/00_cluster_nodes.out
kubectl cluster-info > ${MYBACKUPDIR}/00_cluster_info.out
kubectl api-resources > ${MYBACKUPDIR}/00_cluster_api.out

printf "$(date) -> ${green}Exporting Cluster Scoped Resources${reset}\n"
for OBJECT in namespaces nodes pv crd psp clusterroles clusterrolebindings pc sc ${CRD_CLUSTER}; do
  FILE=${MYBACKUPDIR}/01_k8s-${OBJECT}.yaml
  echo "#**************** SUMMARY ************************" > ${FILE}
  kubectl get ${OBJECT} -o wide 2>&- | awk '{print "# "$0}' >> ${FILE}
  echo "#***************** YAML **************************" >> ${FILE}
  kubectl get ${OBJECT} -o wide -o yaml 2>&- >> ${FILE}
done

printf "$(date) -> ${green}Exporting Namespace Scoped Resources${reset}\n"
NAMESPACES=($(kubectl get ns -o name | awk '{split($0,a,"/"); print a[2]}'))
for INDEX in ${!NAMESPACES[*]}; do
  NAMESPACE=${NAMESPACES[$INDEX]}
  NAMESPACEDIR=${MYBACKUPDIR}/ns-${NAMESPACE}

  printf "\tWorking on: ${bold}$NAMESPACE${reset}\n"
  mkdir -p ${NAMESPACEDIR}
  for OBJECT in cm limitranges pvc pods rc rs quota sa svc ds deploy sts hpa cj jobs ing netpol pdb rolebindings roles ${CRD_NAMESPACED}; do
    FILE=${NAMESPACEDIR}/${NAMESPACE}-${OBJECT}.yaml
    echo "#**************** SUMMARY ************************" > ${FILE}
    kubectl get ${OBJECT} -o wide -n ${NAMESPACE} 2>&- | awk '{print "# "$0}' >> ${FILE}
    echo "#***************** YAML **************************" >> ${FILE}
    kubectl get ${OBJECT} -o wide -o yaml -n ${NAMESPACE} 2>&- >> ${FILE}
  done
done

printf "$(date) -> ${green}Tarball exported to: ${underline}${cyan}${TARFILE}${reset}\n\n"
tar -zcvf ${TARFILE} $MYBACKUPDIR > /dev/null 2>&1
