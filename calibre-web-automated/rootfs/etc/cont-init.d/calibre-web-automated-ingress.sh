#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Generate the nginx config for the ingress-only reverse proxy (cwa-ingress-proxy
# service, listening on 8084 / ingress_port) from its template.
#
# Home Assistant Supervisor's ingress proxy forwards requests to the add-on
# with the /api/hassio_ingress/<token> prefix already stripped, but sends no
# header identifying that prefix. CWA's own root-absolute links (redirects,
# /static/...) therefore escape the ingress iframe and hit Home Assistant's
# own frontend router, producing a 404. CWA's ReverseProxied middleware
# fixes this given the prefix via X-Script-Name, so it's baked into the
# generated nginx config here, once, from the add-on's own (stable for the
# container's lifetime) ingress entry point.
# ==============================================================================

declare ingress_path

ingress_path=$(bashio::app.ingress_entry)

if [ -z "${ingress_path}" ]; then
    bashio::log.warning "Could not determine ingress entry path; the WebUI may 404 when accessed via Home Assistant ingress."
    ingress_path=""
fi

sed "s#__CWA_INGRESS_PATH__#${ingress_path}#g" \
    /etc/nginx/cwa-ingress.conf.template > /etc/nginx/cwa-ingress.conf

bashio::log.info "Ingress reverse proxy configured for path: ${ingress_path}"
