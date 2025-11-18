**What I  need to connect:**
- Local VM
- Sendmail Server in a DigitalOcean Droplet

**How to connect these?**
The VM (10.10.0.2)
- where ELK is  running
--------- Connects to: ---------
DigitalOcean droplet (10.10.0.1) 
- Sendmail server
- Filebeat 

**So we need to** 
1. Install Filebeat in the Sendmail Server
2. Set up the Wireguard connection for both server and client
3. Set up the ELK stack on the VM
4. Check the logs are being parsed and showing up in the Kibana UI
### 1. Filebeat
Install Filebeat on the remote server (sendmail server)
```
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.14.0-amd64.deb
sudo dpkg -i filebeat-8.14.0-amd64.deb
```
### 2. Wireguard
The Droplet will be the server, your local machine will be the client. This doesn't have to be this way, but my VM does not have a public IPv4 so we gotta do what we gotta do.

Generate server key on the Droplet.
```
sudo wg genkey | sudo tee /etc/wireguard/server.key

sudo cat /etc/wireguard/server.key | sudo wg pubkey | sudo tee /etc/wireguard/server.pub

sudo chmod 600 /etc/wireguard/server.key /etc/wireguard/server.pub
```

Enable IPv4 forwarding:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
```

Then we need to modify the configuration:
```
sudo nano /etc/wireguard/wg0.conf
```

It will contain this
Replace "YOUR-SERVER-KEY" with the correct values from `sudo cat /etc/wireguard/server.key`
```
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = [Your KEY]

# Allow forwarding
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
PublicKey = YOUR-SERVER-KEY
AllowedIPs = 10.10.0.2/32
```

Set the permissions
```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```
#### Client Wireguard (Your VM)
Now for your local machine, not the droplet, we have to generate keys as well:
```bash
sudo wg genkey | sudo tee /etc/wireguard/client.key
sudo cat /etc/wireguard/client.key | sudo wg pubkey | sudo tee /etc/wireguard/client.pub
sudo chmod 600 /etc/wireguard/client.key /etc/wireguard/client.pub
```

Create the config for the client:
```bash
sudo nano /etc/wireguard/wg0.conf
```
Should contain this:
```
[Interface]
Address = 10.10.0.2/24
PrivateKey = CLIENT_PRIVATE_KEY_HERE

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
Endpoint = SERVER_PUBLIC_IPV4:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
```

Set permissions again: `sudo chmod 600 /etc/wireguard/wg0.conf`

Check that they are talking to each other:
```bash
sudo wg show
```

If it's working it should show something like this in which it is receiving and sending data:
```bash
interface: wg0
  public key: [REDACTED]
  private key: (hidden)
  listening port: 40460

peer: [REDACTED]
  endpoint: IP-ADDRESS:51820
  allowed ips: 10.10.0.0/24
  latest handshake: 1 minute, 47 seconds ago
  transfer: 323.10 KiB received, 199.19 KiB sent
  persistent keepalive: every 25 seconds
```

### Edit Filebeat Config
Open the file: `sudo nano /etc/filebeat/filebeat.yml`

Let's do a minimal config file:
```bash
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/mail.log

output.logstash:
  hosts: ["10.10.0.2:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
```

Test the config:
```
sudo filebeat test config
```

Then start it:
```
sudo systemctl start filebeat
```
### Elasticsearch
Okay so now we gotta install elasticsearch in our VM (not the droplet):
Step 1. IInstall using docker compose.
```bash                                                                              services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms2g -Xmx2g
      - network.host=0.0.0.0
    ports:
      - "10.10.0.2:9200:9200"
      - "10.10.0.2:9300:9300"
    volumes:
      - esdata:/usr/share/elasticsearch/data
    networks:
      - elk

  kibana:
    image: docker.elastic.co/kibana/kibana:8.14.0
    container_name: kibana
    depends_on:
      - elasticsearch
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    networks:
      - elk

networks:
  elk:
    driver: bridge

volumes:
  esdata:

```
Run the docker `compose up -d`

We need to update the firewall rules:
```bash
sudo ufw allow in on wg0 to 10.10.0.2 port 9200
sudo ufw allow in on wg0 to 10.10.0.2 port 5601
```

Then test to make sure it's working:
 `curl 10.10.0.2:9200
### Logstash
Install Logstash:
Edit the config: `/etc/logstash/conf.d/sendmail.conf  `
The config should be:
```bash
input {
  beats {
    port => 5044
  }
}

filter {
  # Parse the syslog format
  grok {
    match => { 
      "message" => [
        "%{TIMESTAMP_ISO8601:syslog_timestamp} %{SYSLOGHOST:hostname} %{DATA:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:mail_message}",
        "%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:hostname} %{DATA:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:mail_message}"
      ]
    }
  }
  
  # Parse the timestamp
  date {
    match => [ 
      "syslog_timestamp", 
      "ISO8601",
      "MMM  d HH:mm:ss", 
      "MMM dd HH:mm:ss" 
    ]
    target => "@timestamp"
  }
  
  # Only process sendmail/sm-mta logs
  if [program] =~ /sendmail|sm-mta|sm-msp-queue/ {
    
    # Pattern 1: NOQUEUE connections - captures initial connections
    if [mail_message] =~ /NOQUEUE: connect from/ {
      grok {
        match => { "mail_message" => "NOQUEUE: connect from (?:%{HOSTNAME:relay_hostname} )?\[%{IP:sender_ip}\]" }
        add_tag => ["sendmail_connect"]
      }
    }
    
    # Pattern 2: From messages - when mail is received/submitted
    grok {
      match => { "mail_message" => "%{WORD:queue_id}: from=<%{DATA:from_address}>, size=%{NUMBER:message_size:int}, class=%{NUMBER:class:int}, nrcpts=%{NUMBER:nrcpts:int}, msgid=<?%{DATA:message_id}>?, proto=%{WORD:protocol}, daemon=%{DATA:daemon}, relay=%{DATA:relay_from}" }
      add_tag => ["sendmail_from"]
    }
    
    # Extract sender IP from relay field in from messages
    if "sendmail_from" in [tags] and [relay_from] {
      grok {
        match => { "relay_from" => "(?:%{HOSTNAME:from_relay_hostname})?\[%{IP:sender_ip}\]" }
      }
    }
    
    # Pattern 3: To messages - delivery attempts
    grok {
      match => { "mail_message" => "%{WORD:queue_id}: to=<%{DATA:to_address}>, (?:delay=%{DATA:delay}, )?(?:xdelay=%{DATA:xdelay}, )?(?:mailer=%{DATA:mailer}, )?(?:pri=%{NUMBER:priority:int}, )?relay=%{DATA:relay_to}, (?:dsn=%{DATA:dsn}, )?stat=%{WORD:delivery_status}(?: \(%{DATA:status_message}\))?" }
      add_tag => ["sendmail_to"]
    }
    
    # Extract destination relay IP from to messages (this is where mail is being sent TO)
    if "sendmail_to" in [tags] and [relay_to] {
      grok {
        match => { "relay_to" => "(?:%{HOSTNAME:to_relay_hostname})?\[%{IP:destination_ip}\]" }
      }
    }
    
    # Pattern 4: Rejections - spam, policy violations, etc.
    grok {
      match => { "mail_message" => "ruleset=%{WORD:ruleset}, arg1=<?%{DATA:rule_arg1}>?, (?:arg2=%{DATA:rule_arg2}, )?relay=%{DATA:relay_info}(?:, )?reject=%{GREEDYDATA:reject_reason}" }
      add_tag => ["sendmail_reject"]
    }
    
    # Extract IP from rejected connections
    if "sendmail_reject" in [tags] and [relay_info] {
      grok {
        match => { "relay_info" => "(?:%{HOSTNAME:reject_relay_hostname})?\[%{IP:sender_ip}\]" }
      }
    }
    
    # Pattern 5: Lost connection messages
    if [mail_message] =~ /lost connection/ {
      grok {
        match => { "mail_message" => "lost connection with (?:%{HOSTNAME:lost_connection_host} )?\[%{IP:sender_ip}\]" }
        add_tag => ["sendmail_lost_connection"]
      }
    }
    
    # Pattern 6: Timeout messages
    if [mail_message] =~ /timeout/ {
      grok {
        match => { "mail_message" => "timeout waiting for input from (?:%{HOSTNAME:timeout_host} )?\[%{IP:sender_ip}\]" }
        add_tag => ["sendmail_timeout"]
      }
    }
    
    # Fallback: Try to extract any IP from the mail_message if we haven't found one yet
    if ![sender_ip] {
      grok {
        match => { "mail_message" => "\[%{IP:sender_ip}\]" }
      }
    }
  }
  
  # Clean up temporary fields
  mutate {
    remove_field => ["syslog_timestamp"]
  }
}

output {
  elasticsearch {
    hosts => ["http://10.10.0.2:9200"]
    index => "sendmail-logs-%{+YYYY.MM.dd}"
  }
  
  stdout { 
    codec => rubydebug 
  }
}

```

Test the configuration:
```
sudo -u logstash /usr/share/logstash/bin/logstash --path.settings /etc/logstash -t
```
### Kibana views
To view the logs in Kibana we have to go to it and set up a Data View for it.
1. Go to Kibana: `http://10.10.0.2:5601`
2. Click the hamburger menu and select **Management** then select **Stack Management**
3. Click **Data Views** 
4. Click **Create data view**
5. Set:
    - **Name:** `sendmail-*`
    - **Index pattern:** `sendmail-logs-*`
    - **Timestamp field:** `@timestamp`
6. Click **Save data view to Kibana**
7. Navigate on your browser to: `http://10.10.0.2:5601` and it should show the elastic homepage
