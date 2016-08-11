# Don't try fancy stuff like debuginfo, which is useless on binary-only
# packages. Don't strip binary too
# Be sure buildpolicy set to do nothing
%define        __spec_install_post %{nil}
%define          debug_package %{nil}
%define        __os_install_post %{_dbpath}/brp-compress

Summary: A series of scripts and PHP code to archive AMD raw data for long term, and be able to present it to a CAS for re-processing. For use with Dynatrace Data Center Real User Monitoring.
Name: rtmarchive
Version: 1.1.0
Release: 1%{?dist}
License: GPL
SOURCE0 : %{name}-%{version}.tar.gz
URL: https://github.com/cvidler/rtmarchive
BuildArch: x86_64
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: httpd >= 2.4,php >= 5.4,bash >= 4.2,tar,bzip2,gawk,wget,gzip,coreutils,cronie,checkpolicy,policycoreutils,policycoreutils-python
Requires(pre): shadow-utils,glibc-common
Requires(postun): shadow-utils


%pre
/usr/bin/getent passwd %{name} || /usr/sbin/useradd -r -s /sbin/nologin %{name}

%postun
semodule -r rtmarchivepol
firewall-cmd --permanent --remove-port 80/tcp
firewall-cmd --permanent --remove-port 9090-9099/tcp
firewall-cmd --reload
apache-ctl graceful
/usr/sbin/userdel %{name}

%post
firewall-cmd --permanent --add-port 80/tcp
firewall-cmd --permanent --add-port 9090-9099/tcp
firewall-cmd --reload
mkdir -p /var/spool/rtmarchive
chown %{name}:%{name} /var/spool/rtmarchive
chmod 664 /var/spool/rtmarchive
chown %{name}:%{name} /etc/amdlist.cfg
chmod 664 /etc/amdlist.cfg
chown %{name}:%{name} /etc/rumc.cfg
chmod 664 /etc/rumc.cfg
chown %{name}:%{name} -R /var/www/rtmarchive/
chmod 664 /var/www/rtmarchive/activedatasets.conf
chown %{name}:%{name} -R /opt/rtmarchive
chmod 664 /opt/rtmarchive
chown %{name}:%{name} /etc/httpd/conf.d/0_rtmarchive.conf
chmod 664 /etc/httpd/conf.d/0_rtmarchive.conf


crontab -u %{name} /opt/rtmarchive/cron/crontab
echo Compiling SELinux policy, may take a minute
cd /opt/rtmarchive/sepol
./compilepolicy.sh

systemctl enable httpd.service
systemctl start httpd.service



%description
%{summary}


%prep
%setup -q


%build
# Empty section.


%install
rm -rf %{buildroot}
mkdir -p %{buildroot}

# in builddir
cp -a * %{buildroot}


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
#%config(noreplace) %{_sysconfdir}/%{name}/%{name}.conf
#%{_bindir}/*
/etc/*
/opt/rtmarchive/*
/var/www/rtmarchive/*


%changelog
* Thu Jun 02 2016  Chris Vidler <christopher.vidler@dynatrace.com> 1.1.0-1
- First Build, AMD HS compatible release

