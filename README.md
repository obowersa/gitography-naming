Gitography Naming - SRV Service Discovery
=========================================

What is Gitography Naming?
--------------------------

This is the naming component of the gitography project. The idea behind it is
to provide a simple, opinionated approach to service discovery through DNS by
assuming that SRV records point to user accounts/groups which are presented to
an instance.

One of the most important concepts with this implementation is a mapping between
services and user accounts.

What is Gitography Naming not?
------------------------------

As will be shown in the assumptions, this component is not designed to handle
configuration management or orchcestraction. How the DNS records are managed and
how instances are started/built is better handled elsewhere in the pipeline.

Assumptions
------------

Gitography's Naming component assumes the following ( at present ):

- You are running a RHEL based system
- You have DNS configured with the appropriate SRV records
- You have user authentication configured
- Your users have a home drive which is mounted on the container/instance
- Instances have a hostname configured on boot

DNS Record Structure
--------------------

As mentioned in the introduction, Gitography's naming component is very
opinionated about how your DNS structure looks.

The structure of instance names should be as follows:
hostname.component.project.environment.domain
e.g:
pweb01.web.naming.development.obowersa.net

SRV records take the following structure:

_component.project.environment.domain,service_user--service_group.services.project.environment.domain

e.g:

_web.naming.development.obowersa.net,dbapp--demoapp.services.naming.development.obowersa.net


Process User Script
-------------------

The purpose of the naming init script is to find the SRV records associated with
an instance, validate whether or not the appropriate user/group exists and then
hand over to the process_user function.

This function resides with the process_user script. The idea behind this is that
while the DNS structure is well defined, how the user accounts will be handled
is much less concrete and likely to differ with each implementation.

The process user script in the repo is effectively blank bar the function
definition and variable assignment.


Simple example
--------------

For this example we assume the following:

You have an instance with the hostname:
'''bash
 pweb01.web.naming.development.obowersa.net
'''
You have dnsmasq configured with these records

'''bash
srv-host =
_web.naming.development.obowersa.net,weblb--weblb.services.naming.development.obowersa.net

srv-host =
_web.naming.development.obowersa.net,dbapp--oracle.services.naming.development.obowersa.net

'''

You have the following user accounts and groups configured within your authentication
backend

'''bash
User:weblb:/home/weblb
User:dbapp:/home/dbapp

Group:weblb:Members:weblb
Group:oracle:Members:dbapp
'''

You have a very simple implementation of process_user implemented:

'''bash
#!/bin/bash
process_user(){
  local user
  local homedrive
  local group

  user=$1
  homedrive=$2
  group=$3
  sudo -u $user -H sh -c "${homedrive}/initialize.sh"

}
'''bash


With the above in place and name-discovery.sh configured to run on boot, the
following happens:

1. name-discovery.sh is run on hostname: pweb01.web.naming.development.obowersa.net
2. name-discovery.sh queries for any SRV records associated with:
_web.services.development.obowersa.net
3.name-discovery.sh gets the following details back
weblb--weblb.services.naming.development.obowersa.net
dbapp--oracle.services.naming.development.obowersa.net
4. name-discovery.sh proceses record to the following
User:weblb:Group:weblb
User:dbapp:Group:dbapp
5. name-discovery.sh for record we validate that the user/group exists and that the user is
   part of the group. We leaverage getent for this
6. If the user validation passes we call process_user, passing it the
   user/homedrive and group
7. process_user executes the initialize.sh script within each users home
   directory
