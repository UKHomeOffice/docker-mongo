FROM mongo:3.2

COPY set_mongodb_password.sh /set_mongodb_password.sh
COPY docker-entrypoint.sh /entrypoint.sh


ENTRYPOINT ["/entrypoint.sh"]
