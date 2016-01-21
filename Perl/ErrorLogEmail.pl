#!/usr/bin/perl 
use Net::SMTP;
use Authen::SASL;
use Socket;
require 'sys/ioctl.ph';

#日期:2012-09-15_17:25:48 Author:Leo Email:chanyipiaomiao@163.com
#测试平台:CentOS 6.0, CentOS 5.6,Red Hat Enterprise Linux AS release 4

#要读取的日志文件
my $logfile ="/var/log/messages";
my $countfile ="/var/log/last_messages.size";

#发送邮件设置
my $smtp_host = 'smtp.163.com';
my $from = 'xxxx@163.com';
my $password = 'xxxx';
my $to = 'xxxx@163.com';

#定义邮件主题中显示的那个接口的IP地址，默认所eth0
my $interface = "eth0";

#定义正则表达式 
my $pattern = "(?:error|warn)";

#定义邮件主题
my $subject = "Error Log";

#读取上一次日志文件的大小
my $last_size;
if (-z $countfile){
	$last_size = 0;
}
elsif (! -e $countfile ){
	warn "[warning]Can't read \"$countfile\",the file does't exists!\n";
	$last_size = 0;
}
else {
	open COUNTFILEREAD , "<", $countfile or die "Can't read \"$countfile\" : $! ";
	chomp($last_size = <COUNTFILEREAD>);
	close COUNTFILEREAD;
}
	
#写入这次日志文件的大小 到  /var/log/last_messages.size
open COUNTFILEWRITE, ">", $countfile or die "can't write $countfile : $!";
my $this_size = -s $logfile;
print COUNTFILEWRITE $this_size ,"\n";
close COUNTFILEWRITE;

#读取IP地址
sub getIP() {
    my $pack = pack("a*", shift);
    my $socket;
    socket($socket, AF_INET, SOCK_DGRAM, 0);
    ioctl($socket, SIOCGIFADDR(), $pack);
    $ipaddr = inet_ntoa(substr($pack,20,4));
}

#得到日期
sub getDate {
      my ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0 ..5];
      my $date = sprintf "%4d-%02d-%02d %2d:%02d:%02d" ,$year + 1900,$mon + 1 ,$mday ,$hour ,$min ,$sec;
}

#发送邮件函数
sub SendMail {
	my $date = &getDate;
	my $ipaddr = &getIP($interface);
	my $subjects = "$subject\@${ipaddr} Time:$date\n";
	my $smtp = Net::SMTP->new($smtp_host);
	$smtp->auth($from,$password) || print "Email user or password Auth Error!\n";
	$smtp->mail($from);
	$smtp->to($to);
	$smtp->data();
	$smtp->datasend("Subject:$subjects\n");
	$smtp->datasend("\n");
	$smtp->datasend("@_\n\n");
	$smtp->dataend();
	$smtp->quit;
}

#读取日志函数，并找出其中到错误行或者警告行
open MESSAGESLOG , "<", "$logfile" or die "Can't read $logfile : $!";
if ($last_size < $this_size){
	seek(MESSAGESLOG,$last_size,0) || die "$!\n"; #主要语句
	my @errorarray;
	while(<MESSAGESLOG>){
		push @errorarray,$_ if (/$pattern/i);
	}
	&SendMail(@errorarray) if (@errorarray.length != 0 );
}
close MESSAGESLOG;
