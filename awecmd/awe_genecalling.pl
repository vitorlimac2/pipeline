#!/usr/bin/env perl

#input: fasta
#outputs:  ${out_prefix}.faa, ${out_prefix}.fna, ${out_prefix}.out

use strict;
use warnings;
no warnings('once');

use PipelineAWE;
use Getopt::Long;
use Cwd;
umask 000;

# options
my $out_prefix = "genecall";
my $fasta   = "";
my $proc    = 8;
my $size    = 100;
my $type    = "454";
my $help    = 0;
my $options = GetOptions (
        "out_prefix=s" => \$out_prefix,
        "input=s" => \$fasta,
		"proc:i"  => \$proc,
		"size:i"  => \$size,
		"type:s"  => \$type,
        "help!"   => \$help
);

if ($help){
    print_usage();
    exit 0;
}elsif (length($fasta)==0){
    print "ERROR: An input file was not specified.\n";
    print_usage();
    exit __LINE__;
}elsif (! -e $fasta){
    print "ERROR: The input sequence file [$fasta] does not exist.\n";
    print_usage();
    exit __LINE__;
}

my %types = (sanger => 'sanger_10', 454 => '454_30', illumina => 'illumina_10', complete => "complete");
unless (exists $types{$type}) {
    print "ERROR: The input type [$type] is not supported.\n";
    print_usage();
    exit __LINE__;
}

my $run_dir = getcwd;
print "parallel_FragGeneScan.py -v -p $proc -s $size -t $types{$type} -d $run_dir $fasta $out_prefix\n";
PipelineAWE::run_cmd("parallel_FragGeneScan.py -v -p $proc -s $size -t $types{$type} -d $run_dir $fasta $out_prefix");

exit(0);

sub print_usage{
    print "USAGE: awe_genecalling.pl -input=<input fasta> [-out_prefix=<output prefix> -type=<454 | sanger | illumina | complete> -proc=<number of threads, default: 8> -size=<size, default: 100>]\n";
}
