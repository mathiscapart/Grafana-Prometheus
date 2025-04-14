#!/bin/bash

version="${VERSION:-1.0.10}"
arch="${ARCH:-linux-amd64}"
bin_dir="${BIN_DIR:-/usr/local/bin}"

wget "https://github.com/Lusitaniae/apache_exporter/releases/download/v${version}/apache_exporter-${version}.${arch}.tar.gz" \
    -O /tmp/apache_exporter.tar.gz

mkdir -p /tmp/apache_exporter

cd /tmp || { echo "ERROR! No /tmp found.."; exit 1; }

tar xfz /tmp/apache_exporter.tar.gz -C /tmp/apache_exporter || { echo "ERROR! Extracting the apache_exporter tar"; exit 1; }

cp "/tmp/apache_exporter/apache_exporter-${version}.${arch}/apache_exporter" "$bin_dir"
chmod +x "$bin_dir/apache_exporter"

cat <<EOF > /etc/systemd/system/apache_exporter.service
[Unit]
Description=Nginx Exporter for Prometheus
After=network.target

[Service]
User=root
Group=sudo
Type=simple
ExecStart=/usr/local/bin/apache_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable apache_exporter.service
systemctl start apache_exporter.service

echo "SUCCESS! Installation succeeded!"