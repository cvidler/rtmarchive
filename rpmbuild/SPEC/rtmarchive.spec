# Don't try fancy stuff like debuginfo, which is useless on binary-only
# packages. Don't strip binary too
# Be sure buildpolicy set to do nothing
%define        __spec_install_post %{nil}
%define          debug_package %{nil}
%define        __os_install_post %{_dbpath}/brp-compress

Summary: A series of scripts and PHP code to archive AMD raw data for long term, and be able to present it to a CAS for re-processing. For use with Dynatrace Data Center Real User Monitoring.
Name: rtmarchive
Version: 1.0
Release: 1%{?dist}
License: GPL
SOURCE0 : %{name}-%{version}.tar.gz
URL: https://github.com/cvidler/rtmarchive
BuildArch: x86_64
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: httpd >= 2.4,php >= 5.4,bash,touch,tar,bzip2,sha512sum,gawk,wget,wc,gunzip,mktemp,date,chmod,jobs


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
/tmp/*
/root/*


%changelog
* Fri Jan 22 2016  Chris Vidler <christopher.vidler@dynatrace.com> 12.4.1.0012-1
- First Build, SP1 Release

