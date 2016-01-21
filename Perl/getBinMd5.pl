#!/usr/bin/perl 
use Digest::MD5;
use File::Find;

# 2012-12-16 15:24 Leo chanyipiaomiao@163.com
# Blog：http://linux5588.blog.51cto.com

#脚本功能：计算文件的MD5值

#脚本用途：服务器在安装完操作系统后,计算PATH变量里面所有的二进制文件的MD5、计算单个文件MD5值、
#		   计算某个目录(包括子目录)下所有的文件的MD5值记录到文件,等日后再生成一份,然后2份文件进行对比,
#		   即可知道这些文件是否又被改动过.

#脚本用法：
# 脚本名 -p					   [ > 输出的文件名] 	← 该功能是计算PATH变量里面所有文件的MD5值
# 脚本名 -p -f MD5文件		   [ > 输出的文件名] 	← 该功能是计算PATH变量里面所有文件的MD5值并跟上一次生成的MD5文件相对比
# 脚本名 文件1 文件2 文件3 ... [ > 输出的文件名] 	← 该功能是计算指定文件的MD5值
# 脚本名 目录1 目录2 目录3 ... [ > 输出的文件名] 	← 该功能是计算指定目录下所有文件的MD5值
# 脚本名 -c MD5文件1 MD5文件2  [ > 输出的文件名] 	← 该功能是比较同一个目录下所有文件生成的2次MD5文件中有哪些MD5值不一致
# 脚本名 目录 -f MD5文件       [ > 输出的文件名] 	← 该功能是跟上面的功能类似，只是这个不生成文件直接比对
#以上6种用法

#注意事项
# 不能对/proc目录进行计算
# 不能对/(根)进行计算,因为/里面包含/proc
# 不能对挂载在Linux上Windows的共享目录进行计算

#用法提示
$usage = "Usage: scriptname -p | Directory1 ... | File1 ... | -c MD5File1 MD5File2 | Directory -f MD5File [ > OUTFILE]";
$usagecompare = "Usage: scriptname -c MD5File1 MD5File2 [ > OUTFILE]";
$usagepath = "Usage: scriptname -p | -p -f MD5File [ > OUTFILE]";

#判断命令行参数是否为空,为空 则直接计算PATH路径里面所有的二进制文件的MD5值,不为空 
#如果第一个参数是目录,那么调用getDirectoryAllFileMD5 计算目录里面所有文件的MD5值
#如果第一个参数是文件，那么调用getSingleFileMD5 计算命令行参数里面所有文件的MD5值
if (@ARGV) {
	my $arg = $ARGV[0];
	if (-d $arg ) {s
		if ($ARGV[1] eq '-f' && -T $ARGV[2]){
			&compareWithLastMD5File($arg); 
		} else {
			&getDirectoryAllFileMD5(@ARGV);
		}
	} elsif ( -f $arg ) {
		&getSingleFileMD5(@ARGV);
	} elsif ($arg eq '-c' && @ARGV == 3 ) {
		die "$usagecompare\n" unless (-T $ARGV[1] && -T $ARGV[2]);
		&compareWithTwoMD5Files;
	} elsif ($arg eq '-p') {
		if (1 == @ARGV) {
			&getPathBinFileMD5;
		} elsif($ARGV[1] eq '-f' && -T $ARGV[2]) {
			&compareWithLastPathMD5File;
		} else {
			die "$usagepath\n";
		}
	} else {
		die "$usage\n";
	}
} else {
	die "$usage\n";
}

#得到目录下所有文件(包括子目录)的MD5值
sub getDirectoryAllFileMD5 {
	find(\&wantedPrint,@_);
}

#得到PATH变量里面所有的二进制文件的MD5值
sub getPathBinFileMD5 {
	my @path = split /:/,$ENV{PATH}; 
	find(\&wantedPrint,@path);
}

#得到单个文件的MD5值
sub getSingleFileMD5 {
	foreach (@_) {
		if (-R $_) {
			print "$_ ",&getMD5($_),"\n";
		} else {
			print "Can't read $_\n";
			next;
		}
	}
}

#先得到本次PATH变量所有的目录下的文件的MD5值,然后对比以前是生成的MD5文件
sub compareWithLastPathMD5File {
	my @path = split /:/,$ENV{PATH}; 
	&compareWithLastMD5File(@path);
}


#先生成该目录下所有文件的MD5值,然后跟上一次该目录的生成的MD5文件对比
#本次生成的MD5跟上一次生成的MD5文件比对,不一致的输出出来,同时将3个时间输出出来
#如果是新添加的文件则输出出来其3个时间值,atime mtime ctime
sub compareWithLastMD5File {
	find(\&wantedHash,@_);		#这里调用那个回调函数后就会生成一个%thisMD5Hash的哈希
	my $md5file = $ARGV[2];

	open LASTMD5FILE,"<","$md5file" or die "Can't read $md5file : $!\n";
	my $lastMD5Filerecords = (@lastMD5FilerecordsArray = <LASTMD5FILE>);
	%lastMD5Hash = map { split } @lastMD5FilerecordsArray;
	close LASTMD5FILE;

	foreach (keys %thisMD5Hash) {
		$thisMD5Filerecords++;
	}
	&compare($thisMD5Filerecords,$lastMD5Filerecords);
}

#比较2个生成的MD5文件(对同一个目录生成的),找出不同的或者不存在的
sub compareWithTwoMD5Files {
	my ($md5file1,$md5file2) = ($ARGV[1],$ARGV[2]);
	open MD5FILE1,"<","$md5file1" or die "Can't read $md5file1 : $!\n";
	open MD5FILE2,"<","$md5file2" or die "Can't read $md5file2 : $!\n";
	my $file1record = (@file1record = <MD5FILE1>);
	my $file2record = (@file2record = <MD5FILE2>);
	close MD5FILE1;
	close MD5FILE2;

	%thisMD5Hash = map { split } @file1record;
	%lastMD5Hash = map { split } @file2record;
	&compare($file1record,$file2record);
}

#对2个MD5文件进行比较或者是边生成边比对
sub compare {
	my($file1record,$file2record) = ($_[0],$_[1]);

	if ($file1record >= $file2record) {
		%hash1 = %thisMD5Hash;		#这个hash必须是全局的哈希
		%hash2 = %lastMD5Hash;		#这个hash必须是全局的哈希
	} else {
		%hash1 = %lastMD5Hash;
		%hash2 = %thisMD5Hash;
	}

	my $count = 0;		#这个是用来记数的(当找到不同的就加1)
	foreach  (keys %hash1) {
		if (exists $hash2{$_}) {
			if ( $hash1{$_} ne $hash2{$_} ) {
				$count++;
				($atime,$mtime,$ctime) = &getFileAMCTime($_);
				print "Different --> $_\n";
				print "$hash2{$_}\n";
				print "$hash1{$_} Atime:$atime Mtime:$mtime Ctime:$ctime\n\n";
			}
		} else {
			$count++;
			if (-e $_) {
				($atime,$mtime,$ctime) = &getFileAMCTime($_);
				print "Added --> $_ \n$hash1{$_} Atime:$atime Mtime:$mtime Ctime:$ctime\n\n";
			} else {
				print "Deleted --> $_ $hash1{$_}\n\n";
			}
		}
	}
	if ($count == 0) {
		print "Not Found Different !!\n";
	}
}

#遍历条件,找到之后输出
sub wantedPrint {
	if (-f $_ && -R $_) {
		print "$File::Find::name  ",&getMD5($_),"\n";
	}
}

#遍历条件，找到之后形成一个HASH
sub wantedHash {
	if (-f $_ && -r $_) {
		$thisMD5Hash{$File::Find::name} = &getMD5($_);
	}
}

#计算MD5值
sub getMD5 {
	my $file = shift @_;
	open(FH, $file) or die "Can't open '$file': $!\n";
	binmode(FH);
	my $filemd5 = Digest::MD5->new->addfile(FH)->hexdigest;
	close FH;
	return $filemd5;
}

#获取文件的atime,mtime,ctime
sub getFileAMCTime {
	$filename = shift @_;
	my ($atime,$mtime ,$ctime) = (stat ($filename))[8,9,10];
	$atime = &getTime($atime);
	$mtime = &getTime($mtime);
	$ctime = &getTime($ctime);

	#将日期时间格式转换为比较友好的格式
	sub getTime {
		my $time = shift @_;
		my($sec,$min,$hour,$day,$mon,$year) = (localtime $time)[0..5];
		$time = sprintf "%4d-%02d-%02d %2d:%02d:%02d",$year + 1900,$mon + 1,$day,$hour,$min,$sec;
		return $time;
	}
	return $atime,$mtime,$ctime;
}