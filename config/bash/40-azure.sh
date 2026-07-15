# shellcheck shell=bash

export AZURE_CORE_LOGIN_EXPERIENCE_V2=off

azlogin() {
    if az account show >/dev/null 2>&1; then
        local who
        local tenant
        who=$(az account show --query user.name --output tsv 2>/dev/null)
        tenant=$(az account show --query tenantDisplayName --output tsv 2>/dev/null)
        printf 'Already signed in as %s (%s). Run azfresh to reset.\n' \
            "$who" "$tenant"
        return 0
    fi

    printf 'Starting Azure device-code login...\n'
    if [ -t 0 ]; then
        az login --use-device-code --allow-no-subscriptions
    else
        script -qec \
            'az login --use-device-code --allow-no-subscriptions' /dev/null
    fi
}

azfresh() {
    az logout >/dev/null 2>&1 || true
    az account clear >/dev/null 2>&1 || true
    azlogin
}

azwho() {
    az account show \
        --query '{user:user.name, tenant:tenantDisplayName, tenantId:tenantId, subscription:name}' \
        --output yaml
}
