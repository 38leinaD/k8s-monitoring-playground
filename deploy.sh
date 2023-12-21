#!/bin/bash
set -o pipefail # pipe fails with first failing command
set -o nounset # fail when unset vars are read
set -o errexit # exit script on failed command

export CDK_DIR=deployment/aws
export K8S_FOLDER=deployment/k8s

eval $(minikube docker-env)

all() {
    01_build_and_upload_images
    02_k8s_deploy
}

# https://se7entyse7en.dev/posts/how-to-set-up-kubernetes-service-discovery-in-prometheus/
01_build_and_upload_images() {
    ./gradlew :app:build --info -Dquarkus.container-image.build=true
}

02_k8s_deploy() {
    cd $K8S_FOLDER

    kubectl apply -f services.yaml
    kubectl apply -f monitoring/01-namespace.yaml
    kubectl create configmap -n monitoring grafana-dashboard-conf --from-file=../test-dashboard.json
    kubectl apply -f monitoring/
}

access_service() {
	 minikube service app --url
}

access_prom() {
	minikube service prometheus --namespace=monitoring --url
}

access_grafana() {
	minikube service grafana --namespace=monitoring --url
}

_source_cdk_output() {
    jq -r ".\"aws-playground\" | to_entries[] | select(.key | startswith(\"$1\")) | .value" $CDK_DIR/cdk-outputs.json
}

destroy() {
    cd $K8S_FOLDER

    kubectl delete -f services.yaml
    kubectl delete -f monitoring/
}

_kubectl_wait() {
    kubectl wait --for=condition=complete --timeout=90s $1 &
    completion_pid=$!

    kubectl wait --for=condition=failed --timeout=90s $1 && exit 1 &
    failure_pid=$!

    _log_info "Waiting for completion of $1"

    wait -n $completion_pid $failure_pid

    exit_code=$?

    return $exit_code
}

_log_start() {
    printf "%s" "$1"
}

_log_fail() {
    printf " \E[31m%s\E[0m\n" "Failed"
}

_log_ok() {
    printf " \E[32m%s\E[0m\n" "Ok"
}

_log_info() {
    printf "\E[1;37m%s\E[0;0m\n" "$1"
}

_log_warning() {
    printf "\E[1;33m%s\E[0;0m\n" "$1"
}

set +o nounset
if [ -n "$COMP_LINE" ]
then
    compgen -A function | grep -v "^_" | tr '\n' ' '
elif [[ $1 != "" ]];
then
    set -o nounset
    FUNC=$1
    shift
    $FUNC $@
else
    set -o nounset
    echo -e "\E[1;37musage: deploy.sh <command> [args]\E[0;0m"
    echo "commands are:"

    for c in $(compgen -A function);
    do
        if [[ $c != _* ]];
        then
            echo " * $c"
        fi
    done

    _log_warning "Tip: Run 'complete -C $(pwd)/deploy.sh deploy.sh' to get bash completion!"
fi