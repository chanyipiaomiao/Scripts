#!/usr/bin/perl
use File::Find;


# 批量重命名文件的后缀名
# 比如 .3gp 命名为 .mp3

my $gp_root = "/data/data/ivp"; 
my $old_suffix = "\.3gp\$";
my $new_suffix = ".mp3";

my @result;

sub process {
	push @result,$File::Find::name if(/$old_suffix/);
}

sub rename_file {
	foreach my $old (@result){
		(my $new = $old) =~ s/$old_suffix/$new_suffix/;
		if (-e $new){
			warn "Can't rename $old to $new: $new exists\n";
		}elsif (rename $old,$new){
			print "$old --> $new ...OK\n";
		}else {
			warn "rename $old to $new failed: $!\n";
		}
	}
}

find(\&process,$gp_root);
&rename_file;

