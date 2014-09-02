#!/usr/bin/env perl 

#input: .sims file(s), .mapping files(s), sequence file
#outputs: $output, ${output}.index, ${output}.json

use strict;
use warnings;
no warnings('once');

use PipelineAWE;
use Getopt::Long;
use Cwd;
umask 000;

# options
my @in_sims = ();
my @in_maps = ();
my @in_seqs = ();
my $output  = "";
my $memory  = 16;
my $achver  = "1";
my $help    = 0;
my $options = GetOptions (
		"in_sims=s"  => \@in_sims,
		"in_maps=s"  => \@in_maps,
		"in_seqs=s"  => \@in_seqs,
		"output=s"   => \$output,
		"memory=i"   => \$memory,
		"ach_ver=s"  => \$achver,
		"help!"      => \$help
);

if ($help){
    print get_usage();
    exit 0;
}elsif (scalar(@in_sims)==0){
    print STDERR "ERROR: At least one input similarity file is required.\n";
    print STDERR get_usage();
    exit 1;
}elsif (scalar(@in_maps)==0){
    print STDERR "ERROR: At least one input mapping file is required.\n";
    print STDERR get_usage();
    exit 1;
}elsif (scalar(@in_seqs)==0){
    print STDERR "ERROR: An input sequence file was not specified.\n";
    print STDERR get_usage();
    exit 1;
}elsif (length($output)==0){
    print STDERR "ERROR: An output file was not specified.\n";
    print STDERR get_usage();
    exit 1;
}

# get db variables from enviroment
my $achhost = $ENV{'ACH_MONGO_HOST'} || undef;
my $achname = $ENV{'ACH_MONGO_NAME'} || undef;
my $achuser = $ENV{'ACH_MONGO_USER'} || undef;
my $achpass = $ENV{'ACH_MONGO_PASS'} || undef;
unless ( defined($achhost) && defined($achname) && defined($achuser) && defined($achpass) ) {
    print STDERR "ERROR: missing ACH mongodb ENV variables.\n";
    print STDERR get_usage();
    exit 1;
}
my $achopts = "--ach_host ".$achhost." --ach_name ".$achname." --ach_user ".$achuser." --ach_pass ".$achpass." --ach_ver ".$achver;

# temp files
my $sim_file = "sims.filter.".time();
my $map_file = "mapping.".time();
my $seq_file = "sequence.".time();

# cat file sets
if (@in_sims > 1) {
    PipelineAWE::run_cmd("cat ".join(" ", @in_sims)." > ".$sim_file, 1);
    PipelineAWE::run_cmd("rm ".join(" ", @in_sims));
} else {
    PipelineAWE::run_cmd("mv ".$in_sims[0]." ".$sim_file);
}
if (@in_maps > 1) {
    PipelineAWE::run_cmd("cat ".join(" ", @in_maps)." > ".$map_file, 1);
    PipelineAWE::run_cmd("rm ".join(" ", @in_maps));
} else {
    PipelineAWE::run_cmd("mv ".$in_maps[0]." ".$map_file);
}
if (@in_seqs > 1) {
    PipelineAWE::run_cmd("cat ".join(" ", @in_seqs)." > ".$seq_file, 1);
    PipelineAWE::run_cmd("rm ".join(" ", @in_seqs));
} else {
    PipelineAWE::run_cmd("mv ".$in_seqs[0]." ".$seq_file);
}

my $mem = $memory * 1024;
my $run_dir = getcwd;

PipelineAWE::run_cmd("uncluster_sims -v -c $map_file -i $sim_file -o $sim_file.unclust");
PipelineAWE::run_cmd("rm $sim_file $map_file");
PipelineAWE::run_cmd("seqUtil -t $run_dir -i $seq_file -o $seq_file.tab --sortbyid2tab");
PipelineAWE::run_cmd("rm $seq_file");
PipelineAWE::run_cmd("sort -T $run_dir -S ${mem}M -t \t -k 1,1 -o $sim_file.sort $sim_file.unclust");
PipelineAWE::run_cmd("rm $sim_file.unclust");
PipelineAWE::run_cmd("add_seq2sims -v -i $sim_file.sort -o $sim_file.seq -s $seq_file.tab");
PipelineAWE::run_cmd("rm $sim_file.sort $seq_file.tab");
PipelineAWE::run_cmd("sort -T $run_dir -S ${mem}M -t \t -k 2,2 -o $sim_file.final $sim_file.seq");
PipelineAWE::run_cmd("rm $sim_file.seq");

# index file
PipelineAWE::run_cmd("index_sims_file_md5 --verbose $achopts --in_file $sim_file.final --out_file $sim_file.index");

# final output
PipelineAWE::run_cmd("mv $sim_file.final $output");
PipelineAWE::run_cmd("mv $sim_file.index $output.index");

# get stats
my $ann_read = `cut -f1 $output | sort -u | wc -l`;
chomp $ann_read;
my $sim_stat = {read_count_annotated => $ann_read};
foreach my $sim (@in_sims) {
    my $sim_attr = PipelineAWE::read_json($sim.'.json');
    if ($sim_attr->{statistics} && ref($sim_attr->{statistics})) {
        map { $sim_stat->{$_} = $sim_attr->{statistics}{$_} } keys %{$sim_attr->{statistics}};
    }
}

# output attributes
PipelineAWE::create_attr($output.'.json', $sim_stat, {data_type => "similarity", file_format => "blast m8", sim_type => "filter"});
PipelineAWE::create_attr($output.'.index.json', undef, {data_type => "index", file_format => "text"});

exit 0;

sub get_usage {
    return "USAGE: awe_index_sim_seq.pl -in_sims=<one or more input sim files> -in_maps=<one or more input mapping files> -in_seqs=<one or more input fasta files> -output=<output file> [-memory=<memory usage in GB, default is 16> -ach_host=<ach mongodb host> -ach_ver=<ach db ver>]\noutputs: \${output} and \${output}.index\n";
}
