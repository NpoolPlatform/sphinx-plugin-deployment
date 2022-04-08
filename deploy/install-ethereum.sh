#!/bin/bash
export all_proxy=$ALL_PROXY

function info() {
  echo "  <I> -> $1 ~"
}

function usage() {
  echo "Usage:"
  echo "  $1 -[D:a:P:IH:]"
  echo "    -D            Data dir"
  echo "    -a            All proxy"
  echo "    -P            Sphinx proxy addr"
  echo "    -I            Host ip"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'D:a:P:I:' OPT; do
  case $OPT in
    D) DATA_DIR=$OPTARG           ;;
    a) ALL_PROXY=$OPTARG          ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    I) HOST_IP=$OPTARG            ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-ethereum.log
echo > $LOG_FILE
info "RUN install sphinx plugin" >> $LOG_FILE

function install_eth() {
  apt install software-properties-common -y
  apt-get update
  add-apt-repository -y ppa:ethereum/ethereum
  apt-get update
  info "install ethereum" >> $LOG_FILE
  apt-get install ethereum -y >> $LOG_FILE 2>&1
  sleep 10
  cd /home
  info "run geth" >> $LOG_FILE
  mkdir -p $DATA_DIR/ethereum
  nohup geth --http --datadir $DATA_DIR/ethereum > $DATA_DIR/ethereum/geth.log 2>&1 &
}


apt install net-tools -y
netstat -lntup | grep 8545
if [ $? -eq 0 ]; then
#  docker pull uhub.service.ucloud.cn/entropypool/sphinx-plugin:latest
  docker stop ethereum-sphinx-plugin; docker rm ethereum-sphinx-plugin
  docker run -itd --name ethereum-sphinx-plugin --restart=always --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro uhub.service.ucloud.cn/entropypool/sphinx-plugin:latest
  docker exec -it ethereum-sphinx-plugin /home/install-ethereum-sphinx-plugin.sh -P $SPHINX_PROXY_ADDR -I $HOST_IP -a $ALL_PROXY
else
  install_eth
fi



