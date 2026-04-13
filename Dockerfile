FROM flyway/flyway:10

COPY migrations /flyway/sql
COPY flyway.conf /flyway/conf/flyway.conf

CMD ["migrate"]
