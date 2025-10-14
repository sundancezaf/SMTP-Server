### 1. Create the DigitalOcean Droplet
1. A basic ubuntu vm will do
2. Click on the project name, then click on "Access"
3. Open the console
4. Generate the SSH key in local host
5. Add the public SSH key to the "AuthorizedKeys" file in the DigitalOcean VM
6. Log in with "root@your-IP"
7. Note the public IP for this domain
If having trouble with SSH, check out the section in "Troubleshooting" at the end of this guide.

**Create Local Users for Testing**
1. Create additional users that will be used to test authorization: `sudo adduser testuser`

**Setting up the domain to link to your smtp server**

Set the hostname:
```
sudo hostnamectl set-hostname mail.yourdomain.com
sudo nano /etc/hosts
```
The `/etc/hosts` should look like:
```
127.0.0.1   localhost
127.0.1.1   mail.yourdomain.com mail
```
### 2. Get the Domain
1. Go to a domain provider like namecheap and get some domain for like $1
2. Set up the DNS like below:
	1. The MX record is for your mail server

| Type      | Host                | Value               | TTL       |
| --------- | ------------------- | ------------------- | --------- |
| A Record  | @                   | DigitalOcean IP     | Automatic |
| A Record  | mail.yourdomain.com | DigitalOcean IP     | Automatic |
| MX Record | @                   | mail.yourdomain.com | Automatic |
Make sure the priority is "10" for the MX record.
Check that the records are being propagated correctly by searching it in: `https://www.whatsmydns.net/`

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
Changed this line to accept connections from any host to the server:
```
DAEMON_OPTIONS(`Port=smtp,Addr=127.0.0.1, Name=MTA')dnl
```
to
```
DAEMON_OPTIONS(`Port=25, Name=MTA')dnl
```
4, Then deploy the configuration and restart the service:
```
sudo m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf
sudo systemctl restart sendmail
```
5. Check that sendmail is listening on Port 25:
```
sudo netstat -tuln | grep :25
```
6. It should say that it's status is LISTEN. For further checks, do:
```
sudo lsof -i :25
```
This should show that sendmail is using port 25.
7. Try connecting to it with telnet from an external host, example:
```
telnet your-domain 25
```
8. Run the 'EHLO example.com' to test the server is up and running
9. Update the configuration so that messages are queued and released by an admin before they can be delivered:
```bash
define(`confQUEUE_LA', `12')dnl
define(`confQUEUE_DIR', `/var/spool/mqueue')dnl
define(`confDELIVERY_MODE', `queue')dnl
```
10. Add some of those users to a group that will have access to release the queue:
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

The `sendmail-basic-queue.mc` configuration is a simple configuration that will make all incoming emails be queued and not released until an administrator releases the messages. Additional configurations will be added in the following months.