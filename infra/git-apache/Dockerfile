# Apache + Git Smart HTTP（git-http-backend）でリポジトリ配信
FROM httpd:2.4-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl \
 && rm -rf /var/lib/apt/lists/*

COPY git.conf /usr/local/apache2/conf/extra/git.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && echo 'Include conf/extra/git.conf' >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["httpd-foreground"]
