#!/bin/bash
export all_proxy=$ALL_PROXY

function info() {
  echo "  <I> -> $1 ~"
}

function usage() {
  echo "Usage:"
  echo "  $1 -[a:u:p:v:P:t:H:]"
  echo "    -a            All proxy"
  echo "    -u            Rpc user"
  echo "    -p            Rpc password"
  echo "    -v            BTC version"
  echo "    -P            Sphinx proxy addr"
  echo "    -t            Traefik ip"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'D:a:u:p:v:P:t:N:I:' OPT; do
  case $OPT in
    D) DATA_DIR=$OPTARG           ;;
    a) ALL_PROXY=$OPTARG          ;;
    u) RPC_USER=$OPTARG           ;;
    p) RPC_PASSWORD=$OPTARG       ;;
    v) BTC_VERSION=$OPTARG        ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    t) TRAEFIK_IP=$OPTARG         ;;
    N) COIN_NET=$OPTARG           ;;
    I) HOST_IP=$OPTARG            ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-bitcoin.log
echo > $LOG_FILE
info "RUN install bitcoin" >> $LOG_FILE

function install_btc() {
  BTC_TAR=bitcoin-$BTC_VERSION-x86_64-linux-gnu.tar.gz
  info "download $BTC_TAR" >> $LOG_FILE
  all_proxy=$ALL_PROXY curl -o /home/$BTC_TAR https://bitcoin.org/bin/bitcoin-core-$BTC_VERSION/$BTC_TAR >> $LOG_FILE 2>&1
  cd /home
  rm -rf bitcoin-$BTC_VERSION
  tar xf $BTC_TAR
  bitcoin-cli stop
  bitcoin-cli -regtest stop
  sleep 5
  rm -rf /usr/local/bin/bitcoind /usr/local/bin/bitcoin-cli
  cp bitcoin-$BTC_VERSION/bin/bitcoind /usr/local/bin/
  cp bitcoin-$BTC_VERSION/bin/bitcoin-cli /usr/local/bin/
  mkdir -p $DATA_DIR/bitcoin
  cp /home/bitcoin.conf $DATA_DIR/bitcoin/
  sed -i 's/#rpcpassword=.*/rpcpassword='$RPC_PASSWORD'/g' $DATA_DIR/bitcoin/bitcoin.conf
  sed -i 's/#rpcuser=.*/rpcuser='$RPC_USER'/g' $DATA_DIR/bitcoin/bitcoin.conf
  if [ "$COIN_NET" == "main" ]; then
    bitcoind -daemon -datadir=$DATA_DIR/bitcoin -conf=$DATA_DIR/bitcoin/bitcoin.conf -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD >> $LOG_FILE 2>&1
  else
    bitcoind -regtest -addresstype=legacy -daemon -datadir=$DATA_DIR/bitcoin -conf=$DATA_DIR/bitcoin/bitcoin.conf -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD >> $LOG_FILE 2>&1
    echo "rpcwallet=my_wallet" >> $DATA_DIR/bitcoin/bitcoin.conf
  fi
}

function creat_btc_wallet() {
  bitcoin-cli -regtest createwallet my_wallet
  sleep 5
  bitcoin-cli -regtest -generate 101
  sleep 10
}

function run_crontab() {
  apt install cron
  echo "*/10 * * * * /usr/local/bin/bitcoin-cli -regtest -generate 1 > /var/log/cron.log 2>&1" > /var/spool/cron/crontabs/root
  chmod 600 /var/spool/cron/crontabs/root
  service cron start
  sleep 5
  touch /etc/default/locale
}


apt install net-tools -y
netstat -lntup | grep "8332\|18443"
if [ $? -eq 0 ]; then
  docker pull uhub.service.ucloud.cn/entropypool/sphinx-plugin:latest
  docker stop bitcoin-sphinx-plugin; docker rm bitcoin-sphinx-plugin
  docker run -itd --name bitcoin-sphinx-plugin --restart=always --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro uhub.service.ucloud.cn/entropypool/sphinx-plugin:latest
  if [ "$COIN_NET" == "main" ]; then
    docker exec -it bitcoin-sphinx-plugin /home/install-bitcoin-sphinx-plugin.sh -N $COIN_NET -P $SPHINX_PROXY_ADDR -I $HOST_IP -a $ALL_PROXY -u $RPC_USER -p $RPC_PASSWORD -v $BTC_VERSION
  else
    docker exec -it bitcoin-sphinx-plugin /home/install-bitcoin-sphinx-plugin.sh -N $COIN_NET -P $SPHINX_PROXY_ADDR -I $HOST_IP -a $ALL_PROXY -t $TRAEFIK_IP -u $RPC_USER -p $RPC_PASSWORD -v $BTC_VERSION
  fi
else
  install_btc
  if [ "$COIN_NET" == "test" ]; then
    creat_btc_wallet
    run_crontab
  fi
fi


