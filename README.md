# URL Shortener Project

This project provides a URL shortening service using a microservices architecture with Docker, CockroachDB, and RabbitMQ.

## Requirements

- **Node.js**: LTS (preferably Alpine version)
- **Docker**: Version 27.3.1
- **Docker Compose**: Version v2.29.7

## Demo

Access the live demo of this setup at: [desktop-pq51n13.kiko-dorian.ts.net](https://desktop-pq51n13.kiko-dorian.ts.net)

### Zitadel
- mail: zitadel-admin@zitadel.desktop-pq51n13.kiko-dorian.ts.net
- pass: Password1@

### Kibana
- user: elastic
- pass: Re4=aPR5C5z-qb*9hGFr

## Setup Instructions

### 1. Clone the Repository

Clone the repository recursively to include submodules:

```bash
git clone https://github.com/Void-Sentry/url-shortener.git --recursive
cd url-shortener
```

### 2. Set Up CockroachDB Certificates

Run a CockroachDB container to generate certificates for secure communication:

```bash
docker run --rm -it -v $(pwd):/app -w /app cockroachdb/cockroach:v24.2.1 bash -c "
  cd compose/services/database && \
  cockroach cert create-ca --certs-dir=./ --ca-key=ca.key && \
  for node in roach1 roach2 roach3; do \
    cockroach cert create-node \$node roach-lb --certs-dir=./ --ca-key=ca.key && \
    mkdir -p node\${node: -1}/certs && mv node.* node\${node: -1}/certs; \
  done && \
  for client in root zitadel shortener; do \
    cockroach cert create-client \$client --certs-dir=./ --ca-key=ca.key && \
    mkdir -p clients/\$client && mv client.* clients/\$client; \
  done && \
  chown 1000:1000 -R ."
```

### 3. Build Docker Images for Submodules

Build Docker images for each submodule in the project:

```bash
git submodule foreach 'docker buildx build -t $(basename "$name"):latest .'
```

### 4. Start Services with Docker Compose

Start all the services using Docker Compose:

```bash
docker compose -f compose/compose.yaml up -d
```

### 5. Initialize CockroachDB Cluster

Run the following command to initialize the CockroachDB cluster:

```bash
docker exec -it compose-roach1-1 ./cockroach --host roach1:26357 init --certs-dir /run/secrets
```

```bash
docker restart compose-shortener-1
```

### 6. Set Up Elasticsearch and Kibana
Elasticsearch serves as the core data store for log information, while Kibana provides the visualization and dashboard capabilities. Follow these steps to set up and configure them:

a. Configure Elasticsearch Passwords
To start with, you will need to reset the passwords for the kibana_system and elastic users.

Run the following commands inside the Elasticsearch container to reset the passwords:

```bash
docker exec -it compose-elasticsearch-1 bash
elasticsearch-reset-password -u kibana_system -s
```

Copy the password shown in the terminal and update the configuration file at ./compose/services/elk/kibana.yaml under the services.kibana.environment.ELASTICSEARCH_PASSWORD field:

```yaml
services:
  kibana:
    environment:
      ELASTICSEARCH_PASSWORD: <copied_password>
```

Then, reset the password for the elastic user:

```bash
elasticsearch-reset-password -u elastic -s
```
Copy the password shown in the terminal and update the following files:

./compose/services/elk/logstash.yaml under services.logstash.environment.ELASTIC_PASSWORD
./compose/services/elk/data/logstash/logstash.conf under output.elasticsearch.password

```yaml
services:
  logstash:
    environment:
      ELASTIC_PASSWORD: <copied_password>
```

## 7. Set Up Logstash
Logstash will collect logs from your services and push them to Elasticsearch for indexing. The configuration for Logstash is specified in the logstash.conf file.

Ensure the following configurations are set:

```bash
docker compose -f compose/compose.yaml up -d logstash kibana --force-recreate
```

```bash
docker compose -f compose/compose.yaml restart kibana filebeat
```

```bash
docker compose -f compose/compose.yaml restart gateway
```

This will start the Logstash, Kibana, and Filebeat services with the newly configured settings.

### 8. Access Kibana Dashboard
Once everything is up and running, you can access the Kibana dashboard to visualize and analyze the logs.

Open your browser and navigate to http://localhost/kibana to access Kibana.
Log in using the kibana_system credentials, where the username is kibana_system and the password is the one you reset earlier.
In Kibana, you can create visualizations, dashboards, and explore the logs coming from your URL Shortener services.

Your URL shortening service is now set up and running!

### 9. Login with ZITADEL
Use https://oidcdebugger.com/debug as a client to obtain the token.

OIDC Debugger Settings:

- Authorize URI (required): https://localhost/oauth/v2/authorize
- Client ID (required): 292930633691365378
- Response Type (required): code
- Use PKCE?: SHA-256
- Token URI (required for PKCE): https://localhost/oauth/v2/token
- Response Mode (required): form_post

After submitting the form, go to the "PKCE result" section to copy the id_token. - Use this token as a Bearer Token in your requests.

### 10. User Registration
To enable user registration, you need to set up an SMTP server in the ZITADEL instance. This allows for sending verification and password recovery emails, which are essential for the user registration process.
