divert(-1)dnl
#-----------------------------------------------------------------------------
# $Sendmail: debproto.mc,v 8.18.1 2024-03-15 01:52:07 cowboy Exp $
#
# Copyright (c) 1998-2010 Richard Nelson.  All Rights Reserved.
#
# cf/debian/sendmail.mc.  Generated from sendmail.mc.in by configure.
#
# sendmail.mc prototype config file for building Sendmail 8.18.1
#
# Note: the .in file supports 8.15.0 - 9.0.0, but the generated
#	file is customized to the version noted above.
#
# This file is used to configure Sendmail for use with Debian systems.
#
# If you modify this file, you will have to regenerate /etc/mail/sendmail.cf
# by running this file through the m4 preprocessor via one of the following:
#	* make   (or make -C /etc/mail)
#	* sendmailconfig
#	* m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf
# The first two options are preferred as they will also update other files
# that depend upon the contents of this file.
#
# The best documentation for this .mc file is:
# /usr/share/doc/sendmail-doc/cf.README.gz
#
#-----------------------------------------------------------------------------
divert(0)dnl

#
#   Copyright (c) 1998-2005 Richard Nelson.  All Rights Reserved.
#
#  This file is used to configure Sendmail for use with Debian systems.
#

define(`_USE_ETC_MAIL_')dnl
include(`/usr/share/sendmail/cf/m4/cf.m4')dnl
VERSIONID(`$Id: sendmail.mc, v 8.18.1-2 2024-03-15 01:52:07 cowboy Exp $')
OSTYPE(`debian')dnl
DOMAIN(`debian-mta')dnl
dnl # Items controlled by /etc/mail/sendmail.conf - DO NOT TOUCH HERE
undefine(`confHOST_STATUS_DIRECTORY')dnl        #DAEMON_HOSTSTATS=
dnl # Items controlled by /etc/mail/sendmail.conf - DO NOT TOUCH HERE
dnl #
FEATURE(`no_default_msa')dnl
dnl DAEMON_OPTIONS(`Family=inet6, Name=MTA-v6, Port=smtp, Addr=::1')dnl
DAEMON_OPTIONS(`Family=inet,  Name=MTA-v4, Port=25')dnl
dnl DAEMON_OPTIONS(`Family=inet6, Name=MSP-v6, Port=submission, M=Ea, Addr=::1')dnl
DAEMON_OPTIONS(`Family=inet,  Name=MSP-v4, Port=submission, M=Ea, Addr=127.0.0.1')dnl
dnl #

dnl # Queue messages before they are released --- 
dnl # -----------------LAB  MODIFIED---------------------
define(`confQUEUE_LA', `12')dnl
define(`confQUEUE_DIR', `/var/spool/mqueue')dnl
define(`confDELIVERY_MODE', `queue')dnl
dnl # -------------------LAB MODIFIED----------------

dnl # Be somewhat anal in what we allow
define(`confPRIVACY_FLAGS',dnl
`needmailhelo,needexpnhelo,needvrfyhelo,restrictqrun,restrictexpand,nobodyreturn,authwarnings')dnl

dnl # This is supposed to restrict Sendmail to local delivery only
define(`confAUTH_OPTIONS', `A')dnl

dnl # ------------ USER MODIFY HERE-------------------
dnl # setting the domain name
define(`confDOMAIN_NAME', `YOURDOMAIN')dnl
dnl # ------------ USER MODIFY ABOVE-------------------
dnl # setting specific log files
define(`confLOG_FILE', `/var/log/mail.log')dnl
dnl #

dnl # Define connection throttling and window length
define(`confCONNECTION_RATE_THROTTLE', `15')dnl
define(`confCONNECTION_RATE_WINDOW_SIZE',`10m')dnl
dnl #

dnl # Features
dnl #
dnl # use /etc/mail/local-host-names
FEATURE(`use_cw_file')dnl
dnl #

dnl # The access db is the basis for most of sendmail's checking
FEATURE(`access_db', , `skip')dnl
dnl #

dnl # The greet_pause feature stops some automail bots - but check the
dnl # provided access db for details on excluding localhosts...
FEATURE(`greet_pause', `1000')dnl 1 seconds
dnl #

dnl # Delay_checks allows sender<->recipient checking
FEATURE(`delay_checks', `friend', `n')dnl
dnl #

dnl # If we get too many bad recipients, slow things down...
define(`confBAD_RCPT_THROTTLE',`3')dnl
dnl #

dnl # Stop connections that overflow our concurrent and time connection rates
FEATURE(`conncontrol', `nodelay', `terminate')dnl
FEATURE(`ratecontrol', `nodelay', `terminate')dnl


dnl # Dialup/LAN connection overrides
dnl #
include(`/etc/mail/m4/dialup.m4')dnl
include(`/etc/mail/m4/provider.m4')dnl
dnl #

dnl # Default Mailer setup
MAILER_DEFINITIONS
MAILER(`local')dnl
MAILER(`smtp')dnl

