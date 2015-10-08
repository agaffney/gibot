FROM centos:6

RUN echo "Building..." && \
	yum install -y epel-release tar gzip && \
	yum install -y perl-DBD-SQLite2 perl-POE-Component-IRC perl-POE-Component-Syndicator perl-CPAN && \
	echo | cpan -i Weather::Underground Module::Reload && \
	yum clean all

COPY . /gibot/

ENTRYPOINT ["bash", "-c"]
WORKDIR /gibot
CMD ["/gibot/gibot.pl"]
