#!/bin/bash
#
# Copyright (C) 2018 Kauri coin Team
#
# mn_install.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# mn_install.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with mn_install.sh. If not, see <http://www.gnu.org/licenses/>
#

# Only Ubuntu 16.04 supported at this moment.

set -o errexit

# OS_VERSION_ID=`gawk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"'`

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget git python3 python3-pip virtualenv -y

KRC_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo ""`
KRC_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
MN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
MN_EXTERNAL_IP=`curl -s -4 ifconfig.co`

sudo useradd -U -m kauricoin -s /bin/bash
echo "kauricoin:${KRC_DAEMON_USER_PASS}" | sudo chpasswd
sudo wget https://storage.sbg1.cloud.ovh.net/v1/AUTH_e473c1c38f894ec499e6c02673b407b0/dl/kauricoin-0.7.5.1-cli-linux.tar.gz --directory-prefix /home/kauricoin/
sudo tar -xzvf /home/kauricoin/kauricoin-0.7.5.1-cli-linux.tar.gz -C /home/kauricoin/
sudo rm /home/kauricoin/kauricoin-0.7.5.1-cli-linux.tar.gz
sudo mkdir /home/kauricoin/.kauricoincore/
sudo chown -R kauricoin:kauricoin /home/kauricoin/kauricoin*
sudo chmod 755 /home/kauricoin/kauricoin*
echo -e "rpcuser=kauricoinrpc\nrpcpassword=${KRC_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256" | sudo tee /home/kauricoin/.kauricoincore/kauricoin.conf
sudo chown -R kauricoin:kauricoin /home/kauricoin/.kauricoincore/
sudo chown 500 /home/kauricoin/.kauricoincore/kauricoin.conf

sudo tee /etc/systemd/system/kauricoin.service <<EOF
[Unit]
Description=Kauri coin, distributed currency daemon
After=network.target

[Service]
User=kauricoin
Group=kauricoin
WorkingDirectory=/home/kauricoin/
ExecStart=/home/kauricoin/kauricoind

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable kauricoin
sudo systemctl start kauricoin
echo "Booting KRC node and creating keypool"
sleep 140

MNGENKEY=`sudo -H -u kauricoin /home/kauricoin/kauricoin-cli masternode genkey`
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nexternalip=${MN_EXTERNAL_IP}:16061" | sudo tee -a /home/kauricoin/.kauricoincore/kauricoin.conf
sudo systemctl restart kauricoin

echo "Installing sentinel engine"
sudo git clone https://github.com/kaurione/sentinel.git /home/kauricoin/sentinel/
sudo chown -R kauricoin:kauricoin /home/kauricoin/sentinel/
cd /home/kauricoin/sentinel/
sudo -H -u kauricoin virtualenv -p python3 ./venv
sudo -H -u kauricoin ./venv/bin/pip install -r requirements.txt
echo "* * * * * kauricoin cd /home/kauricoin/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" | sudo tee /etc/cron.d/kauricoin_sentinel
sudo chmod 644 /etc/cron.d/kauricoin_sentinel

echo " "
echo " "
echo "==============================="
echo "Masternode installed!"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "SSH password for user \"kauricoin\": ${KRC_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${MN_NAME_PREFIX} ${MN_EXTERNAL_IP}:16061 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
