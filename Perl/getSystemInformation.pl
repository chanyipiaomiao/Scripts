#!/usr/bin/perl
use Cwd;	                      	            #获取当前目录路径
use Sys::Hostname;                            	#获取主机名
use Socket;                                   	#用于获取IP地址
use Net::SMTP;                                	#用于发送邮件
use Authen::SASL;                             	#用于验证邮件的用户名和密码，该模块需要另外安装
use File::Basename;					            #用于取得脚本的名字
use Filesys::Df;								#用于获取磁盘分区信息	该模块需要另外安装
require 'sys/ioctl.ph';                       	#用于获取IP地址
require 'DBI.pm';								#用于连接mysql数据库，不需要请注释掉(前面添加#)，该模块需要另外安装
require 'DBD/mysql.pm';							#用于连接mysql数据库，不需要请注释掉，该模块需要另外安装

# 2012年10月17日 Leo chanyipiaomiao@163.com
# Blog：http://linux5588.blog.51cto.com
# 本脚本只适合Redhat和CentOS系列的Linux系统

#以下定义的变量需要修改
my $interface = "eth0";                         #邮件内容中显示的IP地址和流量统计的接口
my $process_pattern = "httpd|java|mysqld";      #想要查看关键进程的名称
my @partitions = ("/","/data","/backup_svn"); 	#想要查看的磁盘分区
my $logfile ="/var/log/messages";				#要读取的日志文件
my $countfile ="/var/log/last_messages.size";	#用于存放上一次读取日志文件的位置,要有可写入权限
my $error_pattern = "(?:Error|Warning|Invalid)";#用于匹配日志文件中的error行或者warn行或者Invalid行

#发送邮件设置,需要修改
my $site = '163.com';							#用于标识发送邮件时的邮件域
my $smtp_host = 'smtp.163.com' ;          	    #发送的邮件服务器
my $from = 'xxxx@163.com';        #发送邮件的帐号
my $password = 'xxx';                	#帐号密码
my $to = 'xxx@163.com';            	#收件人
my $subject = '服务器系统信息';			#设置邮件主题
my $from_info = '服务器监控邮件';		#设置发件人信息
# my $to2 = '123456@163.com'; 					#设置第二个个收件人
# my $to3 = '321654@qq.com';  					#设置第三个个收件人

#mysql从服务器设置，如果不需要检查mysql主从状态请注释掉这些变量,如果需要检查请修改
my $slave_ip = '192.168.100.253';				#从服务器的IP地址，一般写内网IP地址
my $database_name = 'test';						#连接的数据库，默认是test数据库
my $database_user = 'root';						#从服务器登录mysql的用户名
my $database_password = '';						#从服务器登录mysql的密码

#以下定义的变量不需要修改
my $currentscriptpid = $$;   	                #脚本自身的PID
my $hostname = hostname;                        #得到主机名
my $date = &getDate;							#获取日期
my $currentPwd = cwd;                           #得到当前目录路径
my $proc = "/proc";                             #/proc目录变量
my $ip = &getIP($interface);					#获取IP地址	
my $basename = basename $0;                     #取得脚本的名字
my $temp_log = "/tmp/$basename.log";			#临时文件,用于写入系统信息,用完后会删除
my $run_log = "/tmp/${basename}_Running_Error.log";#脚本运行时错误日志

#调用主函数执行程序
&main;

#主函数调用其他函数
sub main {
	#改变当前工作目录到/proc目录
	chdir "$proc" or die "Can't change $proc: $!\n";

	#打开错误日志文件句柄
	open RUNLOG,">>","$run_log" or warn "Can't write running log\n";
	print RUNLOG "$date\n","=" x 19,"\n";

	#调用所有的函数，把获取到的信息写入到临时文件中
	&getSystemOverview;								#获取系统概览信息
	&getPerSecondTraffic;                           #获取网卡的流量
	&getDiskUsage;									#获取硬盘总容量
	&getMemoryUsuage;                               #获取内存使用情况
	&getSwapUsage;                                  #获取SWAP使用情况
	&getTotalProcess;                               #得到总的进程数量及主要进程的内存占用
	&getHttpPortConnectionStatus;   	            #没有运行web服务，可注释该行
	&checkMysqlMasterSlaveStatus;					#不需要检查mysql主从状态,可注释该行
	&getErrorLogFromMessages;						#获取错误日志行

	#调用写html函数,把获得到的信息写成html格式
	&WriteHtml;

	#关闭错误日志文件句柄
	print RUNLOG "\n";
	close RUNLOG;

	#打开临时文件，读取文件的内容并发送邮件
	open READLOG,"<","$temp_log" or die "Can't read $temp_log : $!";
	@temp_information = <READLOG>;
	close READLOG;
	&SendMail(@temp_information);

	#改变当前工作目录到原来的工作目录
	chdir "$currentPwd" or warn "Can't change to $currentPwd : $!\n";
}

#把获取到的系统信息写成html格式
sub WriteHtml {
	eval {
		open WRITELOG,">","$temp_log" or die "Can't write $temp_log : $!";
		format WRITELOG =
		<html>
			<body>
				<h3>系统信息概览</h3>
				时间: @<<<<<<<<<<<<<<<<<<<< &nbsp; 主机: @<<<<<<<<<<<<<<<<<<<<<<< &nbsp; IP地址: @<<<<<<<<<<<<<<<<<<<<<<<<<   <BR>
						$date 								$hostname 								$ip
				系统当前负载: @<<<<<<<<<<<<<<<<<<<<<<<<<<   <BR>
								$load
				总进程数量: @<<<<<<<<<<  &nbsp; 当前运行的进程的个数: @<<<<<<  <BR>
							$totalProcess 				   	   		  $runningprocess
				系统当前远程登录用户数: @<<<<<<<<<<个  <BR>
							    			$user
				系统已经运行: @<<<<<<<<<<<<<<<<<< <BR>
								$starttime
				系统版本: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< &nbsp; 系统位数: @<<<<< 位 <BR>
									$linux_version						  		 										$linux_bit
				内核版本: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< <BR>
								$kernel_version	
				<h3>当前网卡流量</h3>	
				接收: @<<<<<<<<<<< <BR>
						$RX
				发送: @<<<<<<<<<<< <BR>
						$TX
				<h3>磁盘使用情况</h3>
				@*	
				$disk_size
				--------- <BR>
				@* 
				$partitions		
				<h3>当前内存使用</h3>
				总内存大小: &nbsp; @<<<<<<<<<<< 	<BR>
									$Total_Memory
				已经使用的内存大小: &nbsp; @<<<<<<<<<<<<<<<<<  <BR>
											$Used_Memory
				还剩余的内存大小: &nbsp; @<<<<<<<<<<<<<<<<<<<<	 <BR>
								   		  $Available_Memory	
			    <h3>当前SWAP使用</h3>
			    总大小: &nbsp; @<<<<<<<<<<<<<<<<<<<<<<<<<<	<BR>
			    		 		$total_swap
				已经使用大小: &nbsp; @<<<<<<<<<<<<<<<<<<<<<<<<  <BR>
									  $used_swap
				<h3>当前关键进程信息</h3>
				@* 				<BR>
				$process
				<h3>当前80端口的网络连接状态</h3>
				@* 				<BR>
				$status
				<h3>Mysql 主从复制状态</h3>
				@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<	<BR>
				$mysqlslavestatus
				<h3>@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 日志文件中的错误信息 </h3>
							$logfile
				@*
				$errorlog
			</body>
		</html>
.
		write WRITELOG;
		close WRITELOG; 
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
}

#获取日期
sub getDate {
      my ($sec, $min, $hour, $mday, $mon, $year) = (localtime)[0..5];
      $date = sprintf "%4d-%02d-%02d %2d:%02d:%02d",$year + 1900,$mon + 1 ,$mday ,$hour ,$min ,$sec;
}

#获取IP地址
sub getIP {
	eval {
	 	my $pack = pack("a*", shift);
	    my $socket;
	    socket($socket, AF_INET, SOCK_DGRAM, 0);
	    ioctl($socket, SIOCGIFADDR(), $pack);
		$ipaddr = inet_ntoa(substr($pack,20,4));
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
	return $ipaddr;
}

#发送邮件函数
sub SendMail {
	eval {
	      my $smtp = Net::SMTP->new($smtp_host,Timeout=>30,Hello=>$site);
	      $smtp-> auth($from, $password) or die "Email user or password Auth Error!\n";
	      $smtp-> mail($from);
	      $smtp-> to($to);
	      #$smtp-> to($to,$to2,$to3);		#同时发送给多个人
	      $smtp-> data();
		  $smtp-> datasend("Subject: $subject\n");
		  $smtp-> datasend("From: $from_info\n");
		  $smtp-> datasend("To: $to");
		  $smtp-> datasend("\n" );
		  $smtp-> datasend("Mime-Version:1.0\n");		
		  $smtp-> datasend("Content-Type: text/html;charset=utf-8\n");	
		  $smtp-> datasend("Content-Transfer-Encoding: quoted-printable\n\n");
		  $smtp-> datasend("@_\n" );
	      $smtp-> dataend();
	      $smtp-> quit;
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
}

#获取系统概览信息
sub getSystemOverview {
	&getLinuxVersion;			#获取Linux版本
	&getSystemBit; 				#获取系统的位数
	&getCurrentLoginUser;		#得到当前远程登录用户的数量
	&getSystemAlreadyStartTime;	#得到系统启动时间
	&getRunningProcessAndLoad;	#获取当前运行的进程数量，及CPU的负载
	eval {
	   open VERSION,"<","./version" or die "Can't open version : $!";
	   $version_str = <VERSION>;
	   close VERSION;
	   $where1 = index($version_str,"("); 
	   $kernel_version = substr($version_str,0,$where1);
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}

	#获取Linux版本
	sub getLinuxVersion {
		eval {
			open LINUXVERSION,"<","/etc/redhat-release";
			chomp($linux_version = <LINUXVERSION>);
			close LINUXVERSION;
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@) \n";
		}
	}

	#获取系统的位数
	#getconf LONG_BIT这个命令 可能是读取/usr/libexec/getconf/default(是一个软连接，对应的文件是一个二进制可执行文件)来获取的
	sub getSystemBit {
		eval {
			chomp($linux_bit = `getconf LONG_BIT`);
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}

	#获取当前远程登录的用户
	# w 命令是通过读取 /var/run/utmp 显示结果，但该文件不是文本文件，类型是data类型
	sub getCurrentLoginUser {
		eval {
			$user = 0;
		    foreach (`w`) {
		    	$user++ if /\b\d+\.\d+\.\d+\.\d+\b/;
		    }
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}

	#获取启动时间
	sub getSystemAlreadyStartTime {
		eval {
			open UPTIME,"<","./uptime" or die "Can't read:$!\n";
			$starttime = (split /\s+/,<UPTIME>)[0];
			close UPTIME;
			if ($starttime >= 86400) {
				$starttime = sprintf ("%d 天",$starttime/86400);
			}
			elsif ($starttime < 3600) {
				$starttime = sprintf ("%d 分钟",$starttime/60);
			}
			else {
				$starttime = sprintf ("%d 小时",$starttime/3600);
			}
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}

	#获取CPU的负载和正在运行的进程数量
	sub getRunningProcessAndLoad {
		eval {
			open LOAD,"<","./loadavg" or die "Can't read:$!\n";
			($load1,$load5,$load10,$runningprocess) = (split /\s+/,<LOAD>)[0..3];
			close LOAD;
			$load = $load1 . " " . $load5 . " " . $load10;
			$runningprocess = substr($runningprocess,0,1);
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}
}


#计算总进程数量
sub getTotalProcess {
	eval {
		opendir my $PROCDIR , '.' or die "Unable to open $proc: $!\n";
		my @procdir = readdir $PROCDIR  or die "Unable to read $workdir: $!\n";
		close $PROCDIR;
		
		foreach my $pid (@procdir){
			next if ( $pid eq '.' );
			next if ( $pid eq '..' );
			next unless (-d $pid);
			if ($pid =~ /\b\d+\b/) {
				push @pid_numbers,$pid;
				$totalProcess++;	
			}
		}
		&getPidNameAndMemory(@pid_numbers);
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
	
	#获取每个主要进程信息（内存占用、PID、进程名称）
	sub getPidNameAndMemory {
		eval {
				foreach (@_){
					next if($_ == 1);
					next if($_ == $currentscriptpid);
					open PIDSTATUS,"<","./$_/status" or die "Unable to open $pid_temp: $!\n";
					@pid_name_mem = <PIDSTATUS>;
					close PIDSTATUS;
					if ($pid_name_mem[0] =~ /\b(?:$process_pattern)\b/) {
						$pid_name = (split /\s+/,$pid_name_mem[0])[1];
						$pid_memory = (split /\s+/,$pid_name_mem[15])[1];
						$pid_memory = &FormatSize($pid_memory * 1024);
						$pid_directory = readlink "$_/cwd";

						#把进程的名称、进程PID号、进程所占用的内存、进程的工作目录放到以PID号为名字的数组中
						@$_ = ($pid_name,$_,$pid_memory,$pid_directory);

						#把以PID为数组的名字（也就是引用）放到另外一个数组（包含所有引用），也就成了一个二维数组 
						push @pid_information_array,[@$_];
					}		
				}

				#循环这个二维数组，取出各个进程所对应的信息
				foreach my $pid_array (@pid_information_array){
					$process = "进程名: $$pid_array[0]" . " \&nbsp; " . "PID: $$pid_array[1]" . " \&nbsp; " . "内存占用: $$pid_array[2]" . " \&nbsp; " . "工作目录: $$pid_array[3]" . "<BR>" . "\n$process";			
				}
			};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}
}

#获取总内存大小、已经使用内存大小及可用内存大小使用情况
sub getMemoryUsuage {
	eval {
		open MEMTOTAL,"<","./meminfo" or die "Can't read:$!\n";
		my @memory_usuage;

		#只输出/proc/meminfo文件中前4行，因为前4行包含总内存大小、可用内存大小，从而可以计算出已经使用内存大小
		for (my $var=0; $var<4; $var++) {
			chomp($mem_temp = <MEMTOTAL>);
			push @memory_usuage,(split /\s+/,$mem_temp)[1];
		}
		close MEMTOTAL;

		#计算内存总大小
		$Total_Memory_Temp = $memory_usuage[0];
		$Total_Memory = &FormatSize($Total_Memory_Temp * 1024);

		#计算可用内存大小
		$Available_Memory_Temp = $memory_usuage[1] + $memory_usuage[2] + $memory_usuage[3];
		$Available_Memory = &FormatSize($Available_Memory_Temp * 1024);

		#计算已经使用的内存大小
		$Used_Memory = $Total_Memory_Temp - $Available_Memory_Temp;
		$Used_Memory = &FormatSize($Used_Memory * 1024);
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
}

#计算swap使用情况
sub getSwapUsage {
	eval {
		open SWAP,"<","./swaps" or die "Can't read swaps file : $!";
	    @swap = <SWAP>;
	    close SWAP;
	    ($total_swap,$used_swap) = (split /\s+/,$swap[1])[2,3];
	    $total_swap = &FormatSize($total_swap * 1024);
	    $used_swap = &FormatSize($used_swap * 1024);
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
}

#获取磁盘分区使用情况
sub getDiskUsage {
	eval {
		open PARTITION,"<","./partitions" or die "Can't read: $!\n";
		while (<PARTITION>) {
			if ($. > 2) {
				if (/\b[a-z]+\b/) {
					($total,$disk) = (split)[2,3];
					$disk = '/dev/' . "$disk";
					($sum_used_disk,$sum_available) = &getUsedAndFreeTotalSize($disk);
					$total = &FormatSize($total * 1024);
					$sum_used_disk = &FormatSize($sum_used_disk);
					$sum_available = &FormatSize($sum_available);
					$disk_size = "$disk" . " \&nbsp; " . "总大小: $total" . " \&nbsp; " . "可用: $sum_available" . " \&nbsp; " . "已用: $sum_used_disk". "<BR>" . "\n$disk_size";
				}
			}
		}
		close PARTITION;
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@) \n";
	}

	#计算各分区可用空间总和和已使用空间的总和
	sub getUsedAndFreeTotalSize {
		eval {
			my $disk = shift @_;
			foreach (`df -Pk`) {
				if (/^(?:$disk\d+)/) {
					($used_disk,$available_disk) = (split)[2,3];
					$sum_used_disk = $sum_used_disk + $used_disk;
					$sum_available = $sum_available + $available_disk;			
	    		}
			}
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
		return $sum_used_disk * 1024,$sum_available * 1024;
	}

	#主要分区的使用情况
	&getPartitionSize;
	sub getPartitionSize {
		eval {
				foreach (@partitions){
				my $partitions_size = df("$_");
				$total = &FormatSize($partitions_size->{blocks} * 1024);
				$free = &FormatSize($partitions_size->{bfree} * 1024);
				$used = &FormatSize($partitions_size->{used} * 1024);
				$partitions = "分区: $_" . " \&nbsp; " . "总大小: $total" . " \&nbsp; " . "可用: $free" . " \&nbsp; " . "已用: $used" . "<BR>" . "\n$partitions";
			}
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
	}
}

#获取每秒的流量，以KB/s和MB/s，这里的B是字节
sub getPerSecondTraffic {
	&getTraffic;
	$RX = $traffic[2] - $traffic[0];
	$RX = &formatTrafficSize($RX);
	$TX = $traffic[3] - $traffic[1];
	$TX = &formatTrafficSize($TX);

	#获取发送和接收的流量
	sub getTraffic {
		eval {
			$flag++;			#用于控制递归调用的一个标志
			open TRAFFIC,"<","./net/dev" or die "Can't read /proc/net/dev: $!";
			chomp(@traffic_temp = <TRAFFIC>);
			close TRAFFIC;
			foreach my $j (@traffic_temp) {
				if ($j =~ /\s+$interface/) {
					my($rx,$tx) = (split /\s+/,(split /:/,$j)[1])[0,8];
					push @traffic,$rx;
					push @traffic,$tx;	
				}
			}
			if ($flag < 2) {
				sleep 1;
				&getTraffic;
			}
		};
		if ($@) {
			print RUNLOG "Occurred Error ($@)\n";
		}
		return;
	}
}

#获取80端口的网络连接状态
sub getHttpPortConnectionStatus {
	eval {
		foreach (`netstat -ant`) {
			my ($port,$status) = (split)[3,-1];
			if ($port =~ /:\b80\b$/){
				$network_status{$status}++;
			}
		}
		foreach (keys %network_status){
			$status = "$_ = $network_status{$_}" . "<BR>" . "\n$status";
		}
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
}

#检查Mysql主从状态
sub checkMysqlMasterSlaveStatus {
	eval {
		if(!($connect = DBI->connect("DBI:mysql:database=$database_name;host=$slave_ip",$database_user,$database_password, {'PrintError' => 1}))) {
		    die "Can't Connect Mysql Server $slave_ip\n";
		}
		my $query = $connect->prepare("show slave status");
		$query->execute();

		my $i = 0;
		foreach (@row = $query->fetchrow_array()) {
		        $i++ if /^Yes/i;
		}

		if (2 != $i) {
		   	$mysqlslavestatus = "主从复制出现错误";
		}
		else {
			$mysqlslavestatus = "主从复制正常";
		}
		$query->finish();
		$connect->disconnect();
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@) \n";
	}
}

#获取日志文件中的错行或者警告行
sub getErrorLogFromMessages {
	eval {
		my $last_size;
		if (-z $countfile){
			$last_size = 0;
		}
		elsif (! -e $countfile ){
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

		#读取本次日志文件，并从上一次的位置开始找错误警告行
		open MESSAGESLOG , "<", "$logfile" or die "Can't read $logfile : $!";
		if ($last_size < $this_size){
			seek(MESSAGESLOG,$last_size,0) or die "$!\n"; #主要语句
			while(<MESSAGESLOG>){
				push @errorarray,$_ if (/$error_pattern/i);
			}
		}
		if (@errorarray) {
			foreach (@errorarray) {
				$errorlog = "$_" . "<BR>" . "\n$errorlog";
			}
		} else {
				$errorlog = "没有发现错误或是警告行";
		}
		close MESSAGESLOG;
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@) \n";
	}
}

#格式化流量单位
sub formatTrafficSize {
	my $interface_traffic = eval {
		my $size = shift @_;
		if ($size <= 1024) {
			$size = sprintf("%.2f%s",$size / 1024,"KB/s");
		}
		else {
			$size = sprintf("%.2f%s",$size/1024/1024,"MB/s");
		}
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@) \n";
	}
	return $interface_traffic;
}

#格式化硬盘、内存 大小单位
sub FormatSize {
	my $mb = 1048576;			#MB转化为B(字节),1024 * 1024
	my $gb = 1073741824;		#GB转化为B,1024 * 1024 * 1024
	my $tb = 1099511627776;		#TB转化为B,1024 * 1024 * 1024 * 1024
	my $size_return = eval {
		my $size = shift @_;
		if ($size >= $tb) {
			$size = sprintf("%.2f%s",$size/$tb,"TB");
		} 
		elsif ($size >= $gb && $size < $tb) {
			$size = sprintf("%.2f%s",$size/$gb,"GB");
		}
		elsif ($size < $gb) {
			$size = sprintf("%.2f%s",$size/$mb,"MB");
		}
	};
	if ($@) {
		print RUNLOG "Occurred Error ($@)\n";
	}
	return $size_return;
}

