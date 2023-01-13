#!/usr/bin/env bash
OPENSSL_BIN="/usr/local/opt/openssl@3/bin/openssl"
SED_BIN="/usr/local/bin/gsed"
CERT_PATH="${HOME}/tanzu/certs/registry.pem"
CERT_KEY_PATH="${HOME}/tanzu/certs/registry-key.pem"
CERT_SANS="DNS:registry-svc,DNS:registry-svc.default.svc.cluster.local"
MANIFEST_PATH="$(dirname "$0")/conf/registry/manifest.yaml"

create_and_store_self_signed_cert() {
  "$OPENSSL_BIN" req -x509 -newkey \
    rsa:4096 \
    -keyout "$CERT_KEY_PATH" \
    -out "$CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=localhost" \
    -addext "subjectAltName = $CERT_SANS"
}

# Since this set of scripts will provision multiple clusters as per the TAP
# Reference Architecture, the registry needs to live outside of Kubernetes.
# Instead of creating another cluster just for shared services like this,
# we're going to deploy it as a container and join it to the Kind network.
deploy_docker_registry() {
  docker rm -f registry;
  docker run  \
    --detach \
    --name registry \
    --network kind \
    -p 8443 \
    -e REGISTRY_AUTH=htpasswd \
    -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
    -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
    -e REGISTRY_AUTH_TLS_CERTIFICATE=/certs/certs.pem \
    -e REGISTRY_AUTH_TLS_KEY=/certs/key.pem \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:8443 \
    -v "$HOME/tanzu/registry/certs:/certs" \
    -v "$HOME/tanzu/registry/auth:/auth/htpasswd" \
    -v "$HOME/tanzu/registry/storage:/var/lib/registry" \
    registry:2
}

create_registry_credentials() {
  docker run --rm --entrypoint htpasswd httpd:2 -Bbn admin supersecret
}

confirm_docker_registry() {
  docker run --network kind --rm --entrypoint sh \
    docker -c 'docker login -u admin -p supersecret https://registry:8443'
}

create_certs_dir() {
  mkdir -p "$(dirname "$CERT_PATH")"
}

create_certs_dir &&
  create_and_store_self_signed_cert &&
    create_registry_credentials &&
    deploy_docker_registry &&
    confirm_docker_registry
