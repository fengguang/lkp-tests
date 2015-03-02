#!/bin/sh

# This script is simplifed from detect_system from rvm, and to make it work with /bin/sh:
# https://github.com/wayneeseguin/rvm/blob/master/scripts/functions/detect_system
# ----
#Copyright (c) 2009-2011 Wayne E. Seguin
#Copyright (c) 2011-2015 Michal Papis
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

detect_system()
{
  unset  _system_type _system_name _system_version _system_arch
  export _system_type _system_name _system_version _system_arch
  _system_info="$(command uname -a)"
  _system_type="unknown"
  _system_name="unknown"
  _system_name_lowercase="unknown"
  _system_version="unknown"
  _system_arch="$(command uname -m)"
  case "$(command uname)" in
    (Linux|GNU*)
      _system_type="Linux"
      if
        [ -f /etc/lsb-release ] &&
        GREP_OPTIONS="" \command \grep "DISTRIB_ID=Ubuntu"    /etc/lsb-release >/dev/null
      then
        _system_name="Ubuntu"
        _system_version="$(awk -F'=' '$1=="DISTRIB_RELEASE"{print $2}' /etc/lsb-release | head -n 1)"
        _system_arch="$( dpkg --print-architecture )"
      elif
        [ -f /etc/lsb-release ] &&
        GREP_OPTIONS="" \command \grep "DISTRIB_ID=LinuxMint" /etc/lsb-release >/dev/null
      then
        _system_name="Mint"
        _system_version="$(awk -F'=' '$1=="DISTRIB_RELEASE"{print $2}' /etc/lsb-release | head -n 1)"
        _system_arch="$( dpkg --print-architecture )"
      elif
        [ -f /etc/altlinux-release ]
      then
        _system_name="Arch"
        _system_version="libc-$(ldd --version  | \command \awk 'NR==1 {print $NF}' | \command \awk -F. '{print $1"."$2}' | head -n 1)"
      elif
        [ -f /etc/os-release ] &&
        GREP_OPTIONS="" \command \grep "ID=opensuse" /etc/os-release >/dev/null
      then
        _system_name="OpenSuSE"
        _system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' /etc/os-release | head -n 1)" #'
      elif
        [ -f /etc/SuSE-release ]
      then
        _system_name="SuSE"
        _system_version="$(
          \command \awk -F'=' '{gsub(/ /,"")} $1~/VERSION/ {version=$2} $1~/PATCHLEVEL/ {patch=$2} END {print version"."patch}' < /etc/SuSE-release
        )"
      elif
        [ -f /etc/debian_version ]
      then
        _system_name="Debian"
        _system_version="$(\command \cat /etc/debian_version | \command \awk -F. '{print $1}' | head -n 1)"
        _system_arch="$( dpkg --print-architecture )"
      elif
        [ -f /etc/os-release ] &&
        GREP_OPTIONS="" \command \grep "ID=debian" /etc/os-release >/dev/null
      then
        _system_name="Debian"
        _system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' /etc/os-release | \command \awk -F. '{print $1}' | head -n 1)" #'
        _system_arch="$( dpkg --print-architecture )"
      elif
        [ -f /etc/gentoo-release ]
      then
        _system_name="Gentoo"
        _system_version="base-$(\command \cat /etc/gentoo-release | \command \awk 'NR==1 {print $NF}' | \command \awk -F. '{print $1"."$2}' | head -n 1)"
      elif
        [ -f /etc/arch-release ]
      then
        _system_name="Arch"
        _system_version="libc-$(ldd --version  | \command \awk 'NR==1 {print $NF}' | \command \awk -F. '{print $1"."$2}' | head -n 1)"
      elif
        [ -f /etc/fedora-release ]
      then
        _system_name="Fedora"
        _system_version="$(GREP_OPTIONS="" \command \grep -Eo '[0-9]+' /etc/fedora-release | head -n 1)"
      elif
        [ -f /etc/redhat-release ]
      then
        _system_name="$(
          GREP_OPTIONS="" \command \grep -Eo 'CentOS|ClearOS|Mageia|PCLinuxOS|Scientific|ROSA Desktop|OpenMandriva' /etc/redhat-release 2>/dev/null | \command \head -n 1 | \command \sed "s/ //"
        )"
        _system_name="${_system_name:-RedHat}"
        _system_version="$(GREP_OPTIONS="" \command \grep -Eo '[0-9\.]+' /etc/redhat-release  | \command \awk -F. 'NR==1{print $1}' | head -n 1)"
      elif
        [ -f /etc/centos-release ]
      then
        _system_name="CentOS"
        _system_version="$(GREP_OPTIONS="" \command \grep -Eo '[0-9\.]+' /etc/centos-release  | \command \awk -F. '{print $1}' | head -n 1)"
	  else
        _system_version="libc-$(ldd --version  | \command \awk 'NR==1 {print $NF}' | \command \awk -F. '{print $1"."$2}' | head -n 1)"
      fi
      ;;
  esac
  _system_type=$(printf '%s\n' "$_system_type" | sed 's/[ \/]/_/g')  #"${_system_type//[ \/]/_}"
  _system_name=$(printf '%s\n' "$_system_name" | sed 's/[ \/]/_/g')  #"${_system_name//[ \/]/_}"
  _system_name_lowercase="$(echo ${_system_name} | \command \tr '[A-Z]' '[a-z]')"
  _system_version=$(printf '%s\n' "$_system_version" | sed 's/[ \/]/_/g')  #${_system_version//[ \/]/_}"
  _system_arch=$(printf '%s\n' "$_system_arch" | sed 's/[ \/]/_/g')   #"${_system_arch//[ \/]/_}"
  _system_arch=$(printf '%s\n' "$_system_arch" | sed 's/amd64/x86_64/')  #"${_system_arch/amd64/x86_64}"
  _system_arch=$(printf '%s\n' "$_system_arch" | sed 's/i[123456789]86/i386/')  #"${_system_arch/i[123456789]86/i386}"
}

detect_system

