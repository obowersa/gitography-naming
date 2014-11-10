#!/bin/bash
#
#
#
# Uses SRV records to describe services
# Maps services/apps to usernames
#
# Assumptions:
# User account auth stuff is taken care of
# DNS entries already exist
# Consistant naming pattern for instances:
# Currently centos/RHEL only
#
# hostname.component.project.environment.domain
# pweb01.web.naming.development.obowersa.local
#
# Author: Owen Bower Adams <owen@obowersa.net>

parse_hostname() {
  echo $1 | cut -d '.' -f $2
}

readonly E_NETWORK_SOURCE=3
readonly E_NETWORK_OFFLINE=4
readonly E_INIT_SOURCE=5
readonly E_USER_SOURCE=6
readonly E_USER_FUN=7
readonly E_GROUP_FUN=8
readonly E_TOOL_DIG=9


readonly HOSTNAME_LOCAL="$(hostname -f)"
readonly DOMAINNAME="$(hostname -d)"
readonly ENVIRONMENTNAME="$(parse_hostname $HOSTNAME_LOCAL 4)"
readonly PROJECTNAME="$(parse_hostname $HOSTNAME_LOCAL 3)"
readonly COMPONENTNAME="$(parse_hostname $HOSTNAME_LOCAL 2)"
readonly INSTANCENAME="$(hostname -s)"
readonly SRVNAME="_${DOMAINNAME}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

prereq_checks() {

  if [[ -r /etc/sysconfig/network ]]; then
    . /etc/sysconfig/network 
  else
    err "Unable to source networking sysconfig"
    exit "${E_NETWORK_SOURCE}"
  fi

  if [[ "${NETWORKING}" == "no" ]]; then
    err "Networking is not enabled"
    exit "${E_NETWORK_OFFLINE}"
  fi

  if [[ -r /etc/rc.d/init.d/functions ]]; then
    . /etc/rc.d/init.d/functions
  else
    err "Could not source init.d functions"
    exit "${E_INIT_SOURCE}"
  fi

  if [[ -r /etc/rc.d/init.d/process_user ]]; then
    . /etc/rc.d/init.d/process_user
    if [[ $(declare -fF process_user >/dev/null; echo $?) -eq 1 ]]; then
      err "Could not find process_user function"
      exit "${E_USER_FUN}"
    fi
  else
    err "Could not source process_user"
    exit "${E_USER_SOURCE}"
  fi

  if ! $(hash dig 2>/dev/null); then
    err "Unable to find dig"
    exit "${E_TOOL_DIG}"
  fi
}

split_user() {
  local user_group
  local field
  user_group=$1
  field=$2
  if [[ "${user_group}" == *--* ]]; then
    user_group=${user_group/--/:}
    echo $(echo "${user_group}" | cut -d ':' -f "${field}")
  else
    err "Could not locate group/user delimit: ${user_group}"
  fi
}

validate_user(){
  local user
  local uid
  local group

  user=$(getent passwd $1 | cut -d ':' -f 1)
  group=$(getent group $2)

  if [[ -n "${user}" && -n "${group}" ]];  then
    uid=$(getent passwd $1 | cut -d ':' -f 3)

    if [[ -n $(echo $group | grep -E "(${uid}($|:|,)|${user}($|:|,))") ]]; then
      echo 1
    else 
      echo 0
    fi
  else
    echo 0
  fi

}

get_users() {
  local service_names
  local user_field
  local group_field
  local user
  local homedrive
  local group

  user_field=1
  group_field=2
  service_names=$(dig +short -t srv "${SRVNAME}" | awk '{print $4}' |\
    cut -d '.' -f 1 )

  if [[ -n "${service_names}" ]]; then
    while read service; do
      if [[ -n "${service}" ]]; then
        user=$(split_user "${service}"  "${user_field}")
        group=$(split_user "${service}" "${group_field}") 

        #TODO: Fix the below to make it fit with general style of script
        [[ -z "${user}" ]] && continue
        if [[ $(validate_user "${user}" "${group}") -eq 1 ]]; then
          homedrive=$(getent passwd "${user}" | cut -d -f 6)
          process_user "${user}" "${homedrive}" "${group}"
        else
          err "Could not verify existence of ${user} ${group}"
        fi
      else
        err "Service was null"
      fi
    done <<< "${service_names}"
  else
    err "Could not retrieve any service names"
  fi
}

start() {
  prereq_checks
  get_users
}


case "$1" in
  start)
    start
    ;;
  stop)
    true
    ;;
  *)
    echo $"Usage: $0 {start}"
    exit 1
esac

exit 0
