# SVN + Apache（mod_dav_svn）リポジトリサーバ
FROM httpd:2.4-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      subversion libapache2-mod-svn apache2-utils curl \
 && rm -rf /var/lib/apt/lists/* \
 && cp /usr/lib/apache2/modules/mod_dav_svn.so /usr/local/apache2/modules/ \
 && cp /usr/lib/apache2/modules/mod_authz_svn.so /usr/local/apache2/modules/

COPY svn.conf /usr/local/apache2/conf/extra/svn.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && echo 'Include conf/extra/svn.conf' >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["httpd-foreground"]
