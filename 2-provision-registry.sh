#!/usr/bin/env bash
OPENSSL_BIN="/usr/local/opt/openssl@3/bin/openssl"
REGISTRY_FILES_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/registry"
CERT_PATH="$REGISTRY_FILES_PATH/certs/cert.pem"
CERT_KEY_PATH="$REGISTRY_FILES_PATH/certs/key.pem"
AUTH_FILE_PATH="$REGISTRY_FILES_PATH/auth"
STORAGE_PATH="$REGISTRY_FILES_PATH/storage"
NGINX_CONF_PATH="$(realpath "$(dirname "$(realpath "$0")")")/conf/registry/nginx.conf"
CERT_SANS="DNS:registry"

create_and_store_self_signed_cert() {
  >&2 echo "INFO: Creating self-signed cert for registry..."
  "$OPENSSL_BIN" req -x509 -newkey \
    rsa:4096 \
    -keyout "$CERT_KEY_PATH" \
    -out "$CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=localhost" \
    -addext "subjectAltName = $CERT_SANS" &>/dev/null
}

# Since this set of scripts will provision multiple clusters as per the TAP
# Reference Architecture, the registry needs to live outside of Kubernetes.
# Instead of creating another cluster just for shared services like this,
# we're going to deploy it as a container and join it to the Kind network.
deploy_docker_registry() {
  >&2 echo "INFO: Starting the registry"
  docker rm -f registry-backend >/dev/null &&
  docker run  \
    --detach \
    --name registry-backend \
    --network kind \
    -e REGISTRY_VALIDATION_DISABLED=true \
    -v "$STORAGE_PATH:/var/lib/registry" \
    registry:2 > /dev/null
}

# Needed to work around bug with imgpkg wherein it tries HTTP first for certain
# hosts.
deploy_docker_registry_frontend() {
  >&2 echo "INFO: Starting the registry frontend"
  docker rm -f registry >/dev/null &&
  docker run  \
    --detach \
    --name registry \
    --network kind \
    -p 50000:50000 \
    -v "$NGINX_CONF_PATH:/etc/nginx/nginx.conf" \
    -v "$(dirname "$CERT_PATH"):/certs" \
    -v "$AUTH_FILE_PATH:/auth/htpasswd" \
    nginx
}

create_registry_credentials() {
  test -d "$(dirname "$AUTH_FILE_PATH")" || mkdir -p "$(dirname "$AUTH_FILE_PATH")"
  >&2 echo "INFO: Creating registry credentials"
  docker run --rm --entrypoint htpasswd httpd:2 -Bbn admin supersecret > "$AUTH_FILE_PATH"
}

confirm_docker_registry() {
  docker run --network kind --rm --entrypoint sh \
    docker -c "echo '$(cat "$CERT_PATH")' >> /etc/ssl/certs/ca-certificates.crt && \
docker login -u admin -p supersecret registry:50000"
}

create_certs_dir() {
  mkdir -p "$(dirname "$CERT_PATH")"
}

create_certs_dir &&
  create_and_store_self_signed_cert &&
    create_registry_credentials &&
    deploy_docker_registry &&
    deploy_docker_registry_frontend &&
    confirm_docker_registry
