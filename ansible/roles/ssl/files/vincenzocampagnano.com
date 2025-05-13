server {
    listen 80;
    server_name vincenzocampagnano.com www.vincenzocampagnano.com;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name vincenzocampagnano.com www.vincenzocampagnano.com;

    ssl_certificate /etc/nginx/ssl/domain.cert.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /var/www/html;
    index index.html;

    location / {
         try_files $uri $uri.html $uri/ /index.html;
    }
}

# blocca richieste dirette a indirizzo IP della macchina
server {
  listen 80 default_server;
  listen 443 ssl default_server;

    ssl_certificate /etc/nginx/ssl/domain.cert.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key.pem;

  return 444;  # oppure 403 o 404 (444 chiude la connessione)
}
