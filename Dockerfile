FROM centos:6

RUN echo "Building..." && \
	yum install -y epel-release && \
	yum install -y perl-DBD-SQLite2 perl-POE-Component-IRC perl-POE-Component-Syndicator && \
	curl ftp://ftp.pbone.net/mirror/dag.wieers.com/redhat/el6/en/i386/dag/RPMS/perl-Module-Reload-1.07-1.2.el6.rf.noarch.rpm > /tmp/perl-module-reload.rpm && \
	yum localinstall -y /tmp/perl-module-reload.rpm && \
	rm /tmp/perl-module-reload.rpm && \
	yum clean all

COPY . /gibot/
