#!/bin/bash

[[ "$BASH_SOURCE" == "$0" ]] && {
    echo "Please 'source' this script, don't execute it directly"
    echo "e.g.:"
    echo "$ source $0"
    return 1 2> /dev/null || exit 1
}

export OS_AUTH_URL="https://cloud.api.selcloud.ru/identity/v3"
export OS_IDENTITY_API_VERSION="3"
export OS_VOLUME_API_VERSION="3"

export CLIFF_FIT_WIDTH=1

export OS_PROJECT_DOMAIN_NAME='577073'
export OS_PROJECT_ID='881f877ac435454f9f872772f4b13762'
export OS_TENANT_ID='881f877ac435454f9f872772f4b13762'
export OS_REGION_NAME='ru-3'

export OS_USER_DOMAIN_NAME='577073'
export OS_USERNAME='Ria'

echo "Please enter your OpenStack Password: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT
