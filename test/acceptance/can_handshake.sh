#!/bin/bash
shopt -s expand_aliases

# configuration
CREDIS_NAME=my-redis
CPROXY_NAME=redsmin-proxy
[[ -z $REDSMIN_KEY ]] && echo "❌  REDSMIN_KEY environment variable must be set" && exit 1

# helpers
alias trim="tr -d '\040\011\012\015'"
alias listContainerIds="docker ps -q --no-trunc"
alias getCProxyLog="docker logs $CPROXY_NAME 2>&1"

function cstop-all(){
  docker stop -t 20 $CREDIS_NAME $CPROXY_NAME &> /dev/null
  # because -d & --rm are conflicting in docker v1.12- (#painful)
  docker rm $CREDIS_NAME $CPROXY_NAME &> /dev/null
}

function exit-error(){
  cstop-all
  exit 1
}

# clean containers (just in case)
cstop-all

sleep 25

# start redsmin proxy in background with token, forward output to file
CREDIS=$(docker run -d --name my-redis redis)
CPROXY=$(docker run -d --name redsmin-proxy --link my-redis:local-redis -e REDSMIN_KEY=$REDSMIN_KEY -e REDIS_URI="redis://local-redis:6379" redsmin/proxy)

# wait for 10 seconds
sleep 10

# be sure redis is still up
IS_REDIS_UP=$(listContainerIds | grep $CREDIS | trim)
[[ -z $IS_REDIS_UP ]] && echo "❌  Redis down" && exit-error

# be sure proxy is still up
IS_PROXY_UP=$(listContainerIds | grep $CPROXY | trim)
[[ -z $IS_PROXY_UP ]] && echo "❌  Proxy down" && exit-error

# wait for 10 seconds
sleep 10

# look at redsmin-proxy logs
CPROXY_LOG=`getCProxyLog`
HAS_HANDSHAKED=$(echo $CPROXY_LOG | grep "Handshake succeeded" | trim)
[[ -z $HAS_HANDSHAKED ]] && echo "❌  Proxy could not handshake" && echo $CPROXY_LOG && exit-error

# print info
echo "👍  Everything's good"
echo $CPROXY_LOG

# stop container
cstop-all || true
