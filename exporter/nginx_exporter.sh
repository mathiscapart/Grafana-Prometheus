#!/bin/bash

version="${VERSION:-1.4.1}"
arch="${ARCH:-linux_amd64}"
bin_dir="${BIN_DIR:-/usr/local/bin}"

wget "https://github.com/nginx/nginx-prometheus-exporter/releases/download/v${version}/nginx-prometheus-exporter_${version}_${arch}.tar.gz" \
    -O /tmp/nginx_exporter.tar.gz

mkdir -p /tmp/nginx_exporter

cd /tmp || { echo "ERROR! No /tmp found.."; exit 1; }

tar xfz /tmp/nginx_exporter.tar.gz -C /tmp/nginx_exporter || { echo "ERROR! Extracting the nginx_exporter tar"; exit 1; }

cp "/tmp/nginx_exporter/nginx-prometheus-exporter" "$bin_dir"
chmod +x "$bin_dir/nginx-prometheus-exporter"

cat <<EOF > /etc/systemd/system/nginx_exporter.service
[Unit]
Description=Nginx Exporter for Prometheus
After=network.target

[Service]
User=root
Group=sudo
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nginx_exporter.service
systemctl start nginx_exporter.service

echo "SUCCESS! Installation succeeded!"