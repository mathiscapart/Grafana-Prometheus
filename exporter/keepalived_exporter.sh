#!/bin/bash

version="${VERSION:-1.5.0}"
arch="${ARCH:-linux_amd64}"
bin_dir="${BIN_DIR:-/usr/local/bin}"

wget "https://github.com/mehdy/keepalived-exporter/releases/download/v${version}/keepalived-exporter_${version}_${arch}.tar.gz" \
    -O /tmp/keepalived_exporter.tar.gz

mkdir -p /tmp/keepalived_exporter

cd /tmp || { echo "ERROR! No /tmp found.."; exit 1; }

tar xfz /tmp/keepalived-exporter.tar.gz -C /tmp/keepalived_exporter || { echo "ERROR! Extracting the keepalived_exporter tar"; exit 1; }

cp "/tmp/keepalived_exporter/keepalived-exporter" "$bin_dir"
chmod +x "$bin_dir/keepalived-exporter"

cat <<EOF > /etc/systemd/system/keepalived_exporter.service
[Unit]
Description=Keepalived Exporter for Prometheus
After=network.target

[Service]
User=root
Group=sudo
Type=simple
ExecStart=/usr/local/bin/keepalived-exporter \
  --ka.pid-path=/var/run/keepalived.pid \
  --web.listen-address=":9165"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable keepalived_exporter.service
systemctl start keepalived_exporter.service

echo "SUCCESS! Installation succeeded!"