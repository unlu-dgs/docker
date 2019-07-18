#!/bin/bash
set -euo pipefail
k8s_ns="${POD_NAMESPACE:-default}"

function error() {
    if [ -z "$1" ]; then
        echo "Message: $1"
    fi
    exit 1
}

function get_configmap_name () {
    if [ -z "$1" ]; then
        error "registry id vacio al generar nombre de config-map"
    fi
    echo "arai-lock--$1"
}

function format_status () {
    echo -e "\e[34m> $1"
    echo -e "\e[0m"
}

function format_cmd_output () {
    format_status "$1"
    echo -e "\e[90m$2" | sed 's/^.*/   &/g'
    echo -e "\e[0m"
}

# https://github.com/kubernetes/kubernetes/issues/72794#issuecomment-483502617
function get_deploy_pods_for () {
    local selfLink=$(kubectl get deployment.apps "${1}" -n "${k8s_ns}" -o jsonpath={.metadata.selfLink})
    local selector=$(kubectl get --raw "${selfLink}"/scale | jq -r .status.selector)
    local pods=$(kubectl get pods -n "${k8s_ns}" --field-selector=status.phase==Running -o=name --selector "${selector}" | sed "s/^.\{4\}//")
    echo "${pods}"
}

function get_first_deploy_pod_for () {
    local pods="$(get_deploy_pods_for ${1})"
    echo ${pods} | head -1
}

function save_configmap () {
    local pod=$1
    local registry_id=$2
    local configmap="$(get_configmap_name ${registry_id})"

    format_status "Actualizando configmap ${configmap} para ${1}"
    kubectl exec ${pod} -- sh -c "cat arai.lock" > /tmp/arai.lock
    kubectl create configmap ${configmap} --from-file=/tmp/arai.lock --dry-run -o yaml | kubectl apply -f - 
    rm /tmp/arai.lock
}

function cargar_configmaps () {
    local pods="$(get_deploy_pods_for ${1})"
    local registry_id="$2"

    # update configmap
    for pod in $pods
    do
        format_status "Cargando configmap en ${pod}"
        configmap="$(get_configmap_name ${registry_id})"
        kubectl get configmap ${configmap} -o jsonpath='{.data.arai\.lock}' > /tmp/arai.lock
        kubectl cp /tmp/arai.lock ${pod}:/usr/local/app/arai.lock
        rm /tmp/arai.lock
    done
}

function run_sync () {
    local pods="$(get_deploy_pods_for ${1})"

    for pod in $pods
    do
        kubectl exec ${pod} -- sh -c "chmod +x bin/arai-cli"
        cmd="bin/arai-cli registry:sync --aceptar-pedidos-acceso"
        rs=$(kubectl exec ${pod} -- sh -c "${cmd}")
        format_cmd_output "Output sync en ${pod}" "$rs"
    done
}

# Instalar: curl, bash
ARAI_REGISTRY_URL="http://${ARAI_REGISTRY_SERVICE_HOST}/registry/rest"
CURL_CREDENTIALS="-u registry:registry"

deployments=$(kubectl get deployments -o=name --selector=siu-registry=enabled | cut -d/ -f2-)
for deployment in $deployments
do
    regid=$(kubectl get deployment ${deployment} -o jsonpath='{.metadata.annotations.siu-registry-id}')
    if [ -z "$regid" ]; then
        format_status "Ignorando ${deployment}. No se incluyó la annotation siu-registry-id con el id de instancia"
        continue
    fi

    url="${ARAI_REGISTRY_URL}/packages/${regid}"
    response_code=$(curl ${CURL_CREDENTIALS} --write-out %{http_code} --silent --output /dev/null ${url})

    # si no está registrado ejecutar el add y agregar
    # el arai.lock al configmap
    if [ "$response_code" != "200" ]; then
        pod="$(get_first_deploy_pod_for ${deployment})"
        echo "> Agregando ${deployment}:${pod} a registry"

        # ASEGURAR permiso de ejecución
        kubectl exec ${pod} -- sh -c "chmod +x bin/arai-cli"

        cmd="bin/arai-cli registry:add -m robot -e robot@siu.edu.ar --nombre-instancia=${regid} \${ARAI_REGISTRY_URL}"
        rs=$(kubectl exec ${pod} -- sh -c "${cmd}")
        format_cmd_output "Output add en ${pod}" "$rs"

        # crear configmap
        save_configmap $pod $regid
    fi

    cargar_configmaps $deployment $regid

done

for deployment in $deployments
do
    run_sync $deployment
done

for deployment in $deployments
do
    run_sync $deployment
done

for deployment in $deployments
do
    regid=$(kubectl get deployment ${deployment} -o jsonpath='{.metadata.annotations.siu-registry-id}')
    if [ -z "$regid" ]; then
        format_status "Ignorando ${deployment}. No se incluyó la annotation siu-registry-id con el id de instancia"
        continue
    fi
    pod="$(get_first_deploy_pod_for ${deployment})"
    save_configmap $pod $regid
done
