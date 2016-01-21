#!/usr/bin/perl

my $secrue = "/var/log/secure";
my $hosts = "/etc/hosts.deny" ;
my $count = 10;

#打开读secure文件句柄，然后计算每个IP地址Failed或Invalid出现的次数
open SECRUEFILE, "<", $secrue or die "Can't open $secrue: $!";
foreach (<SECRUEFILE> ){
      $ip{$1}++ if (/(?:Failed|Invalid).*:(\d+\.\d+\.\d+\.\d+)/gi );
}
close SECRUEFILE;

#打开读hosts文件句柄，读入hosts文件内容
open HOSTSREAD, "<", $hosts or die "Can't read $hosts: $!";
chomp(@tempstrings = <HOSTSREAD>);
close HOSTSREAD;

#打开写hosts文件句柄
open HOSTSWRITE, ">>", $hosts or die "Can't create $hosts: $!";

#获取系统日期,判断当天日期是否在hosts文件中，不在则写入hosts文件
my ($mday,$mon,$year) = (localtime)[3..5];
($mday,$mon,$year) = (
    sprintf("%02d", $mday),
    sprintf("%02d", $mon + 1),
    $year + 1900
);
$date = $year."-".$mon."-".$mday;
unless ((grep /$date/,@tempstrings)){
	print HOSTSWRITE "\n";
	print HOSTSWRITE "###########$date###########\n";
}

#定义子程序，如果hosts已经有了的IP地址，则不写入hosts文件。
sub ip_noexists_write {
      my $temp_ip = shift @_;
      if (0 == @tempstrings){
            print HOSTSWRITE "sshd:$temp_ip\n";
      } else {
            print HOSTSWRITE "sshd:$temp_ip\n" unless (grep /$temp_ip/,@tempstrings);
      }
}

#如果次数大于$count的值，就写入到hosts文件
foreach (keys %ip){
      #print "$_ = $ip{$_} \n";
      &ip_noexists_write($_) if ($ip{$_} >= $count);
}
close HOSTSWRITE;
