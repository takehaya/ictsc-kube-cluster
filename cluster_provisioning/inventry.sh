#!/bin/sh
set -eu
dir=""
if [ $# -ne 1 ]; then
    dir=`terraform workspace show`
fi

if [ -e ./terraform.tfstate.d/${dir}/terraform.tfstate ]; then
    rm -f hosts
    if [ "`uname`" == "Darwin" ]; then
        ip=`cat ./terraform.tfstate.d/${dir}/terraform.tfstate | jq  '.outputs[].value[]' | sed -e 's/\$/,/' | sed -e :loop -e 'N; $!b loop' -e 's/\n/ /g'| sed -e 's/,$//g'`
    else
        # linux style sed
        ip=`cat ./terraform.tfstate.d/${dir}/terraform.tfstate | jq  '.outputs[].value[]' | sed -e 's/\$/,/' | sed -e ':loop; N; $!b loop; s/\n/ /g'| sed -e 's/,$//g'`
    fi
    cat << EOS > hosts
{
    "cloud_servers": {
        "hosts": {$ip}
    }
}
EOS
    chmod +x hosts
fi
