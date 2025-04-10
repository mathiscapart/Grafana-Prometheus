#!/bin/bash

# Variables

EXPORTER_VERSION="0.17.2"  # Replace with the desired version
DOWNLOAD_URL="https://github.com/prometheus/mysqld_exporter/releases/download/v${EXPORTER_VERSION}/mysqld_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
INSTALL_DIR="/usr/local/bin"
USER="prometheus"
GROUP="prometheus"
MYSQL_USER="exporter"     # MySQL user with appropriate privileges
MYSQL_PASSWORD="password_exporter" # MySQL password
MYSQL_ROOT_PASSWORD="root"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
CONFIG_DIR="/etc/mysqld_exporter"


# Function to check the last command status and exit on failure
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error occurred in the previous command. Exiting.."
        exit 1
    fi
}

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Function to check if MySQL/MariaDB is installed and running
check_mysql() {
    if command -v mysql >/dev/null 2>&1; then
        echo "MySQL/MariaDB is installed."
        if systemctl is-active --quiet mysqld || systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
            echo "MySQL/MariaDB is running."
            return 0
        else
            echo "MySQL/MariaDB is not running. Please start it before proceeding."
            return 1
        fi
    else
        echo "MySQL/MariaDB is not installed. Please install it before proceeding."
        return 1
    fi
}

# Check if MySQL/MariaDB is installed and running
if ! check_mysql; then
    exit 1
fi

# Detect the operating system
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported operating system."
    exit 1
fi

case $OS in
    ubuntu|debian)
        echo "Updating package list..."
        apt-get update
        check_status

        echo "Installing wget and tar..."
        apt-get install -y wget tar
        check_status
        ;;
    centos|fedora|rhel)
        echo "Installing wget and tar..."
        yum install -y wget tar
        check_status
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Function to print messages
function print_message {
    echo "[INFO] $1"
}

# Create system group and user for myslqd_exporter
echo "Creating system group and user for mysqld_exporter..."
if ! getent group $GROUP > /dev/null 2>&1; then
  groupadd --system $GROUP
  check_status
else
  echo "Group $GROUP already exists."
fi

if ! id -u $USER > /dev/null 2>&1; then
  useradd --system -g $GROUP --no-create-home --shell /sbin/nologin $USER
  check_status
else
  echo "User $USER already exists."
fi

# Download and install mysqld_exporter
print_message "Downloading mysqld_exporter version ${EXPORTER_VERSION}..."
wget $DOWNLOAD_URL
check_status

print_message "Extracting mysqld_exporter..."
tar -xzf "mysqld_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
mv "mysqld_exporter-${EXPORTER_VERSION}.linux-amd64/mysqld_exporter" $INSTALL_DIR/
check_status

# Create the configuration directory
echo "Creating mysqld_exporter configuration directory..."
mkdir -p $CONFIG_DIR
check_status

# Set permissions
echo "Setting permissions for Mysqld Exporter binaries..."
chown $USER:$GROUP $INSTALL_DIR/mysqld_exporter
chmod +x $INSTALL_DIR/mysqld_exporter
chown -R $USER:$GROUP $CONFIG_DIR
check_status

# Cleaning up
rm -rf "mysqld_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz" "mysqld_exporter-${EXPORTER_VERSION}.linux-amd64"
check_status

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS 'mysqld_exporter'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}'; GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost'; FLUSH PRIVILEGES;"


# Create a configuration file for mysqld_exporter
print_message "Creating mysqld_exporter configuration..."
cat <<EOL | tee /etc/systemd/system/mysqld-exporter.service
[Unit]
Description=Mysqld exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$GROUP
Type=simple
ExecStart=$INSTALL_DIR/mysqld_exporter \
    --config.my-cnf $CONFIG_DIR/my.cnf \
    --collect.global_status \
    --collect.info_schema.innodb_metrics \
    --collect.auto_increment.columns \
    --collect.info_schema.processlist \
    --collect.binlog_size \
    --collect.info_schema.tablestats \
    --collect.global_variables \
    --collect.info_schema.query_response_time \
    --collect.info_schema.userstats \
    --collect.info_schema.tables \
    --collect.perf_schema.tablelocks \
    --collect.perf_schema.file_events \
    --collect.perf_schema.eventswaits \
    --collect.perf_schema.indexiowaits \
    --collect.perf_schema.tableiowaits \
    --collect.slave_status \
    --web.listen-address=0.0.0.0:9104

Restart=always

[Install]
WantedBy=multi-user.target
EOL
check_status

# Create my.cnf for the exporter with multiple instances
print_message "Creating MySQL configuration for mysqld_exporter..."
cat <<EOF | tee $CONFIG_DIR/my.cnf
[client]
user=${MYSQL_USER}
password=${MYSQL_PASSWORD}
host=${MYSQL_HOST}
port=${MYSQL_PORT}
EOF
check_status

# Reload systemd and start the mysqld_exporter service
print_message "Reloading systemd..."
sudo systemctl daemon-reload
check_status

echo "Enabling mysqld_exporter service"
systemctl enable mysqld-exporter
check_status

print_message "Starting mysqld_exporter service..."
systemctl start mysqld-exporter
check_status

print_message "mysqld_exporter installation and configuration completed!"
print_message "You can check the status with: sudo systemctl status mysqld-exporter"