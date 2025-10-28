## Domain and Basic Sendmail Configuration
Any cloud provider and a basic vm will do the job. The following directions are for DigitalOcean.
### 1. Create a DigitalOcean Droplet
1. Create a new project
2. On the left-hand side, click on "Droplets" and then click "Create Droplet"
3. Choose your region
4. Choose a basic Ubuntu vm
5. Then choose the latest version and the most basic options
6. For the Authentication Method, if you don't already have an ssh key in your local host, generate a new one and add it here.
7. Finalize all the other details
8. After your droplet has been created, note the public IP for the droplet.
9. Now in your local host you can log in to your new droplet with "root@digitalOcean-droplet-IP"

**Create Local Users for Testing**

Create additional users that will be used to test authorization: `sudo adduser testuser`

### 2. Get the Domain
1. Go to a domain provider like namecheap and get a domain, the cheapest one will do.
	Set up the DNS like below (The MX record is for your mail server):

| Type      | Host                | Value               | TTL       |
| --------- | ------------------- | ------------------- | --------- |
| A Record  | @                   | DigitalOcean IP     | Automatic |
| A Record  | mail.yourdomain.com | DigitalOcean IP     | Automatic |
| MX Record | @                   | mail.yourdomain.com | Automatic |

Make sure the priority is "10" for the MX record.
Check that the records are being propagated correctly by searching it in: `https://www.whatsmydns.net/`

**Setting up the domain to link to your smtp server**

2. Back in the droplet,set the hostname:
```bash
sudo hostnamectl set-hostname mail.yourdomain.com
sudo nano /etc/hosts
```
3. The `/etc/hosts` should look like:
```bash
127.0.0.1   localhost
127.0.1.1   mail.yourdomain.com mail
```
### 3. Setting up Sendmail
1. **Install the sendmail server**
```bash
sudo apt install sendmail sendmail-bin -y
```
2. Add your domain to `/etc/mail/local-host-names` so people can send email to different users. All the users should be able to receive mail at `user@yourdomain`.
```bash
makemap hash /etc/mail/local-host-names < /etc/mail/local-host-names
```
3. **Accept mail from external sources**
Change this line to accept connections from any host to the server:
```bash
DAEMON_OPTIONS(`Port=smtp,Addr=127.0.0.1, Name=MTA')dnl
```
to
```bash
DAEMON_OPTIONS(`Port=25, Name=MTA')dnl
```
4, Then deploy the configuration and restart the service:
```bash
sudo m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf && systemctl restart sendmail
```
5. Check that sendmail is listening on Port 25:
```bash
sudo netstat -tuln | grep :25
```
6. It should say that it's status is LISTEN. For further checks, do:
```bash
sudo lsof -i :25
```
This should show that sendmail is using port 25.
7. Try connecting to it with telnet from an external host, example:
```bash
telnet your-domain 25
```
8. Run the 'EHLO example.com' to test the server is up and running

## Updating Sendmail Configuration to Use Mail Queue
The following updates enable the queue so that messages are not automatically delivered. Instead, the messages are placed in the queue and are "released" by an admin.

1. Update the configuration so that messages are queued and released by an admin before they can be delivered:
```bash
define(`confQUEUE_LA', `12')dnl
define(`confQUEUE_DIR', `/var/spool/mqueue')dnl
define(`confDELIVERY_MODE', `queue')dnl
```
2. Add some of those users to a group that will have access to release the queue:
```bash
#create a group
sudo groupadd mailqueue

# add user to the group
sudo usermod -aG mailqueue theUsername

#check permissions
groups theUsername

#change owernship to new users
sudo chown root:mailqueue /var/spool/mqueue
sudo chmod 750 /var/spool/mqueue
```

3. Refresh the configuration and restart the Sendmail service to ensure new configuration is applied
```bash
sudo m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf && systemctl restart sendmail
```



The `sendmail-basic-queue.mc` configuration is a simple configuration that will make all incoming emails be queued and not released until an administrator releases the messages. Additional configurations will be added in the following months.