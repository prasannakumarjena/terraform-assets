#! /bin/bash
mkdir -p /var/cache/kubernetes-install
cd /var/cache/kubernetes-install
readonly SALT_MASTER='172.20.0.9'
readonly INSTANCE_PREFIX='${cluster_id}'
readonly NODE_INSTANCE_PREFIX='${cluster_id}-minion'
readonly CLUSTER_IP_RANGE='10.244.0.0/16'
readonly ALLOCATE_NODE_CIDRS='true'
readonly SERVER_BINARY_TAR_URL='https://s3.amazonaws.com/${s3_bucket}/devel/kubernetes-server-linux-amd64.tar.gz'
readonly SALT_TAR_URL='https://s3.amazonaws.com/${s3_bucket}/devel/kubernetes-salt.tar.gz'
readonly ZONE='${availability_zone}'
readonly KUBE_USER='${kube_user}'
readonly KUBE_PASSWORD='${kube_pass}'
readonly SERVICE_CLUSTER_IP_RANGE='10.0.0.0/16'
readonly ENABLE_CLUSTER_MONITORING='influxdb'
readonly ENABLE_CLUSTER_LOGGING='false'
readonly ENABLE_NODE_LOGGING='false'
readonly LOGGING_DESTINATION='elasticsearch'
readonly ELASTICSEARCH_LOGGING_REPLICAS='1'
readonly ENABLE_CLUSTER_DNS='true'
readonly ENABLE_CLUSTER_UI='true'
readonly DNS_REPLICAS='1'
readonly DNS_SERVER_IP='10.0.0.10'
readonly DNS_DOMAIN='cluster.local'
readonly ADMISSION_CONTROL='NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota'
readonly MASTER_IP_RANGE='10.246.0.0/24'
readonly KUBELET_TOKEN=$$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
readonly KUBE_PROXY_TOKEN=$$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
readonly DOCKER_STORAGE='aufs'
readonly MASTER_EXTRA_SANS='IP:10.0.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local,DNS:kubernetes-master'
readonly NUM_MINIONS='1'



apt-get update
apt-get install --yes curl

download-or-bust() {
  local -r url="$$1"
  local -r file="$${url##*/}"
  rm -f "$$file"
  until [[ -e "$${1##*/}" ]]; do
    echo "Downloading file ($$1)"
    curl --ipv4 -Lo "$$file" --connect-timeout 20 --retry 6 --retry-delay 10 "$$1"
    md5sum "$$file"
  done
}



install-salt() {
  local salt_mode="$$1"

  if dpkg -s salt-minion &>/dev/null; then
    echo "== SaltStack already installed, skipping install step =="
    return
  fi

  echo "== Refreshing package database =="
  until apt-get update; do
    echo "== apt-get update failed, retrying =="
    echo sleep 5
  done

  mkdir -p /var/cache/salt-install
  cd /var/cache/salt-install

  DEBS=(
    libzmq3_3.2.3+dfsg-1~bpo70~dst+1_amd64.deb
    python-zmq_13.1.0-1~bpo70~dst+1_amd64.deb
    salt-common_2014.1.13+ds-1~bpo70+1_all.deb
  )
  if [[ "$${salt_mode}" == "master" ]]; then
    DEBS+=( salt-master_2014.1.13+ds-1~bpo70+1_all.deb )
  fi
  DEBS+=( salt-minion_2014.1.13+ds-1~bpo70+1_all.deb )
  URL_BASE="https://storage.googleapis.com/kubernetes-release/salt"

  for deb in "$${DEBS[@]}"; do
    if [ ! -e "$${deb}" ]; then
      download-or-bust "$${URL_BASE}/$${deb}"
    fi
  done

  for deb in "$${DEBS[@]}"; do
    echo "== Installing $${deb}, ignore dependency complaints (will fix later) =="
    dpkg --skip-same-version --force-depends -i "$${deb}"
  done

  # This will install any of the unmet dependencies from above.
  echo "== Installing unmet dependencies =="
  until apt-get install -f -y; do
    echo "== apt-get install failed, retrying =="
    echo sleep 5
  done

  # Log a timestamp
  echo "== Finished installing Salt =="
}



echo "Waiting for master pd to be attached"
attempt=0
while true; do
  echo Attempt "$$(($$attempt+1))" to check for /dev/xvdb
  if [[ -e /dev/xvdb ]]; then
    echo "Found /dev/xvdb"
    break
  fi
  attempt=$$(($$attempt+1))
  sleep 1
done

echo "Mounting master-pd"
mkdir -p /mnt/master-pd
mkfs -t ext4 /dev/xvdb
echo "/dev/xvdb  /mnt/master-pd  ext4  noatime  0 0" >> /etc/fstab
mount /mnt/master-pd

mkdir -m 700 -p /mnt/master-pd/var/etcd
mkdir -p /mnt/master-pd/srv/kubernetes
mkdir -p /mnt/master-pd/srv/salt-overlay
mkdir -p /mnt/master-pd/srv/sshproxy

ln -s -f /mnt/master-pd/var/etcd /var/etcd
ln -s -f /mnt/master-pd/srv/kubernetes /srv/kubernetes
ln -s -f /mnt/master-pd/srv/sshproxy /srv/sshproxy
ln -s -f /mnt/master-pd/srv/salt-overlay /srv/salt-overlay

if ! id etcd &>/dev/null; then
  useradd -s /sbin/nologin -d /var/etcd etcd
fi
chown -R etcd /mnt/master-pd/var/etcd
chgrp -R etcd /mnt/master-pd/var/etcd



mkdir -p /srv/salt-overlay/pillar
cat <<EOF >/srv/salt-overlay/pillar/cluster-params.sls
instance_prefix: '$$(echo "$$INSTANCE_PREFIX" | sed -e "s/'/''/g")'
node_instance_prefix: '$$(echo "$$NODE_INSTANCE_PREFIX" | sed -e "s/'/''/g")'
cluster_cidr: '$$(echo "$$CLUSTER_IP_RANGE" | sed -e "s/'/''/g")'
allocate_node_cidrs: '$$(echo "$$ALLOCATE_NODE_CIDRS" | sed -e "s/'/''/g")'
service_cluster_ip_range: '$$(echo "$$SERVICE_CLUSTER_IP_RANGE" | sed -e "s/'/''/g")'
enable_cluster_monitoring: '$$(echo "$$ENABLE_CLUSTER_MONITORING" | sed -e "s/'/''/g")'
enable_cluster_logging: '$$(echo "$$ENABLE_CLUSTER_LOGGING" | sed -e "s/'/''/g")'
enable_cluster_ui: '$$(echo "$$ENABLE_CLUSTER_UI" | sed -e "s/'/''/g")'
enable_node_logging: '$$(echo "$$ENABLE_NODE_LOGGING" | sed -e "s/'/''/g")'
logging_destination: '$$(echo "$$LOGGING_DESTINATION" | sed -e "s/'/''/g")'
elasticsearch_replicas: '$$(echo "$$ELASTICSEARCH_LOGGING_REPLICAS" | sed -e "s/'/''/g")'
enable_cluster_dns: '$$(echo "$$ENABLE_CLUSTER_DNS" | sed -e "s/'/''/g")'
dns_replicas: '$$(echo "$$DNS_REPLICAS" | sed -e "s/'/''/g")'
dns_server: '$$(echo "$$DNS_SERVER_IP" | sed -e "s/'/''/g")'
dns_domain: '$$(echo "$$DNS_DOMAIN" | sed -e "s/'/''/g")'
admission_control: '$$(echo "$$ADMISSION_CONTROL" | sed -e "s/'/''/g")'
num_nodes: $$(echo "$${NUM_MINIONS}")
EOF

readonly BASIC_AUTH_FILE="/srv/salt-overlay/salt/kube-apiserver/basic_auth.csv"
if [ ! -e "$${BASIC_AUTH_FILE}" ]; then
  mkdir -p /srv/salt-overlay/salt/kube-apiserver
  (umask 077;
    echo "$${KUBE_PASSWORD},$${KUBE_USER},admin" > "$${BASIC_AUTH_FILE}")
fi

kubelet_token=$$KUBELET_TOKEN
kube_proxy_token=$$KUBE_PROXY_TOKEN

mkdir -p /srv/salt-overlay/salt/kube-apiserver
readonly KNOWN_TOKENS_FILE="/srv/salt-overlay/salt/kube-apiserver/known_tokens.csv"
(umask u=rw,go= ; echo "$$kubelet_token,kubelet,kubelet" > $$KNOWN_TOKENS_FILE ;
echo "$$kube_proxy_token,kube_proxy,kube_proxy" >> $$KNOWN_TOKENS_FILE)

mkdir -p /srv/salt-overlay/salt/kubelet
kubelet_auth_file="/srv/salt-overlay/salt/kubelet/kubernetes_auth"
(umask u=rw,go= ; echo "{\"BearerToken\": \"$$kubelet_token\", \"Insecure\": true }" > $$kubelet_auth_file)

mkdir -p /srv/salt-overlay/salt/kube-proxy
kube_proxy_kubeconfig_file="/srv/salt-overlay/salt/kube-proxy/kubeconfig"
cat > "$${kube_proxy_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
users:
- name: kube-proxy
  user:
    token: $${kube_proxy_token}
clusters:
- name: local
  cluster:
     insecure-skip-tls-verify: true
contexts:
- context:
    cluster: local
    user: kube-proxy
  name: service-account-context
current-context: service-account-context
EOF

mkdir -p /srv/salt-overlay/salt/kubelet
kubelet_kubeconfig_file="/srv/salt-overlay/salt/kubelet/kubeconfig"
cat > "$${kubelet_kubeconfig_file}" <<EOF
apiVersion: v1
kind: Config
users:
- name: kubelet
  user:
    token: $${kubelet_token}
clusters:
- name: local
  cluster:
     insecure-skip-tls-verify: true
contexts:
- context:
    cluster: local
    user: kubelet
  name: service-account-context
current-context: service-account-context
EOF

service_accounts=("system:scheduler" "system:controller_manager" "system:logging" "system:monitoring" "system:dns")
for account in "$${service_accounts[@]}"; do
  token=$$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
  echo "$${token},$${account},$${account}" >> "$${KNOWN_TOKENS_FILE}"
done




echo "Downloading binary release tar ($$SERVER_BINARY_TAR_URL)"
download-or-bust "$$SERVER_BINARY_TAR_URL"

echo "Downloading binary release tar ($$SALT_TAR_URL)"
download-or-bust "$$SALT_TAR_URL"

echo "Unpacking Salt tree"
rm -rf kubernetes
tar xzf "$${SALT_TAR_URL##*/}"

echo "Running release install script"
sudo kubernetes/saltbase/install.sh "$${SERVER_BINARY_TAR_URL##*/}"


mkdir -p /etc/salt/minion.d
echo "master: $$SALT_MASTER" > /etc/salt/minion.d/master.conf

cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-master
  cloud: aws
  cbr-cidr: "$${MASTER_IP_RANGE}"
EOF

if [[ -n "$${DOCKER_OPTS}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  docker_opts: '$$(echo "$$DOCKER_OPTS" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "$${DOCKER_ROOT}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  docker_root: '$$(echo "$$DOCKER_ROOT" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "$${KUBELET_ROOT}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  kubelet_root: '$$(echo "$$KUBELET_ROOT" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "$${MASTER_EXTRA_SANS}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  master_extra_sans: '$$(echo "$$MASTER_EXTRA_SANS" | sed -e "s/'/''/g")'
EOF
fi

mkdir -p /etc/salt/master.d
cat <<EOF >/etc/salt/master.d/auto-accept.conf
auto_accept: True
EOF

cat <<EOF >/etc/salt/master.d/reactor.conf
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/highstate-new.sls
EOF

install-salt master

echo "open_mode: True" >> /etc/salt/master
echo "auto_accept: True" >> /etc/salt/master

service salt-master start
service salt-minion start
