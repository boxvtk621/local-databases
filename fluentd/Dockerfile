FROM fluent/fluentd:v1.16-debian-1

USER root
# Сервер ES 8.x — клиент elasticsearch 9.x даёт ошибки bulk; после плагина принудительно оставляем только 8.x.
RUN fluent-gem install fluent-plugin-elasticsearch -v 5.4.0 && \
    fluent-gem install elasticsearch -v 8.19.3 && \
    fluent-gem uninstall elasticsearch -v 9.3.1 -x -I || true && \
    fluent-gem uninstall elasticsearch-api -v 9.3.1 -x -I || true
USER fluent
