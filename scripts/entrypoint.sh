#!/usr/bin/env bash

set -o nounset
set -e

########## VARIABLES ##########

##### PKI #####

# CA bundle
export MONGODB_SSL_CA="${MONGODB_SSL_CA:-/etc/ssl/certs/ca-bundle.crt}"

# Server key / certificate
export MONGODB_SSL_CERT="${MONGODB_SSL_CERT:-/mnt/certs/tls.pem}"
export MONGODB_SSL_KEY="${MONGODB_SSL_KEY:-/mnt/certs/tls-key.pem}"

# Concatenated server key / certificate file
export MONGODB_SSL_SERVER_BUNDLE="${MONGODB_SSL_SERVER_BUNDLE:-${MONGODB_HOME}/tls/mongodb.pem}"

# Server certificate subject
export MONGODB_SSL_CERT_SUBJECT="${MONGODB_SSL_CERT_SUBJECT:-$(openssl x509 \
-in "${MONGODB_SSL_CERT}" \
-noout \
-subject \
-nameopt multiline \
| sed -n 's# *commonName *= ##p'\
)}"

# Admin user key / certificate
export MONGODB_SSL_ADMIN_CERT="${MONGODB_SSL_ADMIN_CERT:-/mnt/certs/mongo-admin.pem}"
export MONGODB_SSL_ADMIN_KEY="${MONGODB_SSL_ADMIN_KEY:-/mnt/certs/mongo-admin-key.pem}"

# Concatenated admin key / certificate file
export MONGODB_SSL_ADMIN_BUNDLE="${MONGODB_SSL_ADMIN_BUNDLE:-${MONGODB_HOME}/tls/mongo-admin-combined.pem}"

##### MongoDB settings #####

export MONGODB_MAX_CONNECTION_RETRIES="${MONGODB_MAX_CONNECTION_RETRIES:-30}"
export MONGODB_REPLICA_SET_NAME="${MONGODB_REPLICA_SET_NAME:-Replica}"
export MONGODB_REPLICA_SET_SEED="${MONGODB_REPLICA_SET_SEED:-${MONGODB_SSL_CERT_SUBJECT}}"
export MONGODB_WIRED_TIGER_CACHE_SIZE="${MONGODB_WIRED_TIGER_CACHE_SIZE:-1}"

##### Users and Databases #####

# Admin user
export MONGODB_ADMIN_USER_USERNAME="${MONGODB_ADMIN_USER_USERNAME:-CN=mongo-admin,OU=local-development-mongo-users,ST=London,C=GB}"
export MONGODB_ADMIN_USER_AUTH_DB="${MONGODB_ADMIN_USER_AUTH_DB:-admin}"
export MONGODB_ADMIN_USER_AUTH_TYPE="${MONGODB_ADMIN_USER_AUTH_TYPE:-X509}"
export MONGODB_ADMIN_USER_PASSWORD="${MONGODB_ADMIN_USER_PASSWORD:-}"
export MONGODB_ADMIN_USER_ROLES="${MONGODB_ADMIN_USER_ROLES:-admin:root}"

# Client 1
export MONGODB_USER_1_USERNAME="${MONGODB_USER_1_USERNAME:-CN=mongo-client,OU=local-development-mongo-users,ST=London,C=GB}"
export MONGODB_USER_1_AUTH_DB="${MONGODB_USER_1_AUTH_DB:-DB}"
export MONGODB_USER_1_AUTH_TYPE="${MONGODB_USER_1_AUTH_TYPE:-X509}"
export MONGODB_USER_1_PASSWORD="${MONGODB_USER_1_PASSWORD:-}"
export MONGODB_USER_1_ROLES="${MONGODB_USER_1_ROLES:-DB:readWrite}"

##### Logging #####

export MONGODB_ENTRYPOINT_DEBUG="${MONGODB_ENTRYPOINT_DEBUG:-0}"
export MONGODB_MONGOCONF_LOG_LEVEL="${MONGODB_MONGOCONF_LOG_LEVEL:-INFO}"

########## PREAMBLE ##########

# Generate concatenated key / certificate file for server
if [ ! -f "${MONGODB_SSL_SERVER_BUNDLE}" ]; then
    cat "${MONGODB_SSL_KEY}" "${MONGODB_SSL_CERT}" > "${MONGODB_SSL_SERVER_BUNDLE}"
fi

# Generate concatenated key / certificate file for admin user
if [ ! -f "${MONGODB_SSL_ADMIN_BUNDLE}" ]; then
    cat "${MONGODB_SSL_ADMIN_KEY}" "${MONGODB_SSL_ADMIN_CERT}" > "${MONGODB_SSL_ADMIN_BUNDLE}"
fi

# When MongoDB is running with authentication enabled, but no users are defined,
# an initial "localhost exception" is created. This exception allows the
# creation of an initial admin user via an unauthenticated connection to "localhost".
#
# Using the localhost exception can be problematic when both authentication and SSL
# are enabled ("localhost" may not be a valid SAN on the server's certificate).
#
# To avoid this issue, we can initialise MongoDB with authentication, but without SSL.
#
# Once an initial administrative user has been created, the localhost
# exception immediately closes.
#
# At this point, we can restart MongoDB using both authentication and SSL,
# then access the database using the newly created administrative user.
#
# N.B. If the initial administrative user uses X509 authentication,
# SSL must be enabled for the user to access the database.

# Common server startup options (including authentication)
base_startup_command="mongod -f /etc/mongod.conf --auth --wiredTigerCacheSizeGB ${MONGODB_WIRED_TIGER_CACHE_SIZE}"

# Start server without SSL for first-run initialisation
initial_startup="${base_startup_command} --bind_ip 127.0.0.1"

# Standard startup with SSL and replicaSet options set
main_startup="${base_startup_command} --replSet ${MONGODB_REPLICA_SET_NAME} --bind_ip_all --setParameter opensslCipherConfig=HIGH:!EXPORT:!aNULL@STRENGTH --sslMode requireSSL --clusterAuthMode x509 --sslPEMKeyFile ${MONGODB_SSL_SERVER_BUNDLE} --sslCAFile ${MONGODB_SSL_CA}"

# Marker file indicating whether first-run initialisation has been completed
db_initialisation_marker_file='/data/db/.db_initialised'

# Marker file indicating whether this node has initialised / joined a replicaSet
rs_initialisation_marker_file='/data/db/.rs_initialised'

# First-run database initialisation

if [ ! -f "${db_initialisation_marker_file}" ]; then

    cat <<DB_INITIALISATION_TEXT
==> Database initialisation marker file [ ${db_initialisation_marker_file} ] not found
==> Attempting to initialise database
DB_INITIALISATION_TEXT

    # Start MongoDB in the background (auth, no SSL, no replicaSet)
    echo "==> Starting MongoDB as a background process"

    if [ ${MONGODB_ENTRYPOINT_DEBUG} -eq 1 ]; then
        ${initial_startup} &
    else
        ${initial_startup} &> /dev/null &
    fi

    # Use mongoconf to create initial admin user
    if mongoconf initialise_db; then
        echo $(date) > "${db_initialisation_marker_file}"
        echo "==> Successfully initialised database"
    else
        echo "==> ERROR: Failed to initialise database"
    fi

    # Stop background MongoDB process
    echo "==> Terminating background instance of MongoDB"
    ${initial_startup} --shutdown

fi

# Initialise or join replicaSet

if [ ! -f "${rs_initialisation_marker_file}" ]; then

    cat <<RS_INITIALISATION_TEXT
==> ReplicaSet initialisation marker file [ ${rs_initialisation_marker_file} ] not found
==> Attempting to manage replicaSet membership
RS_INITIALISATION_TEXT

    # (Re)start MongoDB in the background (auth, ssl, replicaSet)
    echo "==> Starting MongoDB as a background process"

    if [ ${MONGODB_ENTRYPOINT_DEBUG} -eq 1 ]; then
        ${main_startup} &
    else
        ${main_startup} &> /dev/null &
    fi

    # Use mongoconf to initialise / join replicaSet
    if mongoconf initialise_rs; then
        echo $(date) > "${rs_initialisation_marker_file}"
        echo "==> Successfully managed replicaSet membership"
    else
        echo "==> ERROR: Failed to initialise replicaSet"
    fi

    # Stop background MongoDB process

    echo "==> Terminating background instance of MongoDB"
    ${main_startup} --shutdown

fi

# Execute start-up tasks

echo "==> Attempting to execute start-up tasks"

# When running in Kubernetes, we want to restrict the user management process
# to the pod with ordinal 0 (to avoid repeating identical modifications)

# Outside of Kubernetes, (i.e. when our hostname doesn't match
# the Kubernetes pod naming convention), we should always manage users

if hostname | grep -qx 'mongo-.*-0' || hostname | grep -qxv 'mongo-.*-[[:digit:]]*'; then

    # (Re)start MongoDB in the background (auth, ssl, replicaSet)
    echo "==> Starting MongoDB as a background process"

    if [ ${MONGODB_ENTRYPOINT_DEBUG} -eq 1 ]; then
        ${main_startup} &
    else
        ${main_startup} &> /dev/null &
    fi

    # Use mongoconf to execute start-up tasks
    if mongoconf; then
        echo "==> Successfully executed start-up tasks"
    else
        echo "==> ERROR: Failed to execute start-up tasks"
    fi

    # Stop background MongoDB process

    echo "==> Terminating background instance of MongoDB"
    ${main_startup} --shutdown

fi

########## MAIN ##########

# Run MongoDB as PID 1

echo "==> Starting MongoDB"

if [ $# -eq 0 ]; then
    exec ${main_startup}
else
    exec "$@"
fi
