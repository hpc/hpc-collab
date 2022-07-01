export LANG=${LANL:-en_US.UTF-8}
export LANGUAGE=${LANGUAGE:-${LANG}}
export LC_ALL=${LC_ALL:-${LANG}}

export TZ=${TZ:-MST7MDT}

export LANL_PROTO=http
export LANL_PROXY_HOST=proxyout.lanl.gov
export LANL_PROXY_PORT=8080
export LANL_PROXY=${LANL_PROTO}://${LANL_PROXY_HOST}:${LANL_PROXY_PORT}
export http_proxy=${LANL_PROXY}
export https_proxy=${LANL_PROXY}
export proxy=${LANL_PROXY}
