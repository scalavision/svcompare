#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp;
use Set::Scalar;
use File::Basename;
use Sort::Naturally;
use Bio::SeqIO;
use List::Util qw(max min);
use List::MoreUtils qw(uniq);
use Scalar::Util qw(looks_like_number);

##################################################################
#notes: filter column contains <NA> values - ignore 
#
#
##################################################################

usage() unless(@ARGV > 1);
my ($vcf_file, $tech_file) = ($ARGV[0], $ARGV[1]);


#my $data_by_event_href = generate_data_by_event($vcf_file,$tech_file);
# show_data_by_event($data_by_event_href);

# my $data_by_caller_href = generate_data_by_caller($vcf_file,$tech_file);
# show_data_by_caller($data_by_caller_href);

##########################################################################################
# 											Generate statistics							 #
##########################################################################################
sub gen_statistics {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($events_href,$caller_href) = ($_[0],$_[1]); 

	######################################################
	# You may pass either of the data structures 
	#  (either by row or column) for a specific analysis
	######################################################
	# function1();	
	# function2();
	# ........
}

##########################################################################################
#									Do not change code below							 #
##########################################################################################
# 											By caller (column)							 #
##########################################################################################
sub generate_data_by_caller {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($datafile,$tech_map) = ($_[0],$_[1]); 

	my %data = ();
	my $headers_href;
	my $data = load_data($datafile);
	foreach my $line (@$data) {
		next unless($line =~ /#chrom/i || $line =~ /^\d/); #assumes chromosomes are numbers
		
		if($line =~ /^\d/) {
			insert_events_in_data($line,$headers_href, \%data);
		} else {
			$headers_href = get_headers($line) ;		
		}
	}
	return \%data;
}
sub insert_events_in_data {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 3);
	my ($str, $headers_href, $data_href) = ($_[0],$_[1],$_[2]);

	my %hash = ();
	#######################
	# replace caller string with whatever caller appears first in the datafile
	#######################
	my $key = lc("HG002.TE_insertions.recover_filt_mod.vcf"); 
	my $pos = $headers_href->{$key};
	$hash{"caller_start_pos"} = $pos;
		
	my @tokens = split(/\t/, $str);

	$hash{"caller_end_pos"} = $#tokens;
	
	for(my $i = 0; $i < $pos; $i++) {
		my $k = $headers_href->{$i};
	 	$hash{$k} = $tokens[$i];
	}
	my $stop = get_end_location($hash{"info"});
	my $start = $hash{"pos"};
	$hash{"start"} = $start;
	$hash{"stop"} = $stop;	


	for(my $i = $pos; $i < scalar(@tokens); $i++) {
		next if($tokens[$i] =~ /NaN/i);		#ignore invalid calls
		
		my $caller = $headers_href->{$i};
		my $event = $tokens[$i];
		
		my $events = get_event_types_with_coord($event);
		
		my $caller_record = { 
			$hash{"id"} => {
				"caller" => $caller, "id" => $hash{"id"}, "start" => $hash{"start"}, 
				"stop" => $hash{"stop"}, "events" => $events
			}
		};
		$data_href->{$caller}->{$hash{"id"}} = $caller_record->{$hash{"id"}};
		$data_href->{$caller}->{"caller_count"}++;
	}
}
sub show_data_by_caller {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($data_href) = ($_[0]); 

	while(my ($caller,$records) = each(%$data_href)) {
		#####################
		# #show number of records (events or lines) for each caller
		#####################
		# print $caller,",",$records->{"caller_count"},"\n"; 

		#####################
		# show records (events) only for one caller
		#####################
		if($caller eq "hg002.te_insertions.recover_filt_mod.vcf") {
			while(my ($record_id,$regions) = each(%$records)) {
			
				#show number of regions a caller has detected an event 
				unless(ref($regions)) {
					print "$record_id,$regions\n";
					next;
				}

				print "caller: ", $regions->{"caller"},"\n";
				print "id: ", $regions->{"id"},"\n";
				print "start: ", $regions->{"start"},"\n";
				print "stop: ", $regions->{"stop"},"\n";
				
				my $events = $regions->{"events"};
				print "GT: ", $events->{"gt"},"\n";
				print "LN: ", $events->{"length"},"\n";
				print "DV: ", $events->{"dv"},"\n";
				
				my $types = $events->{"types"};
				foreach my $type (@$types) {
					print "mutation types: $type\n";
				}
				
				my $coords = $events->{"coords"};
				while(my ($type, $coord_aref) = each(%$coords)) {
					print "$type\n";
					foreach my $coord (@$coord_aref) {
						print "\tchr:", $coord->{"chr"}," start:", $coord->{"start"}," stop:", $coord->{"stop"},"\n";
					}
				}
				print "##########################\n";
			}
		}
	}

}
			
##########################################################################################
# 											By event (row)								 #
##########################################################################################
sub generate_data_by_event {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($datafile,$tech_map) = ($_[0],$_[1]); 

	my %data = ();
	my $headers_href;
	my $data = load_data($datafile);
	foreach my $line (@$data) {
		next unless($line =~ /#chrom/i || $line =~ /^\d/); #assumes chromosomes are numbers
		
		if($line =~ /^\d/) {
			my $record_href = get_record($line,$headers_href);
			$data{$record_href->{"id"}} = $record_href if($record_href->{"caller_count"} > 0);
		} else {
			$headers_href = get_headers($line) ;		
		}
	}
	return \%data;
}
sub get_record {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($str, $headers_href) = ($_[0],$_[1]);

	my %hash = ();
	my $key = lc("HG002.TE_insertions.recover_filt_mod.vcf");
	my $pos = $headers_href->{$key};
	$hash{"caller_start_pos"} = $pos;
	
	my @tokens = split(/\t/, $str);
	$hash{"caller_end_pos"} = $#tokens;
	
	for(my $i = 0; $i < $pos; $i++) {
		my $k = $headers_href->{$i};
	 	$hash{$k} = $tokens[$i];
	}

	for(my $i = $pos; $i < scalar(@tokens); $i++) {
		next if($tokens[$i] =~ /NaN/i);		#ignore invalid 
		$hash{"caller_count"}++;		
		
		my $caller_id = $headers_href->{$i};
		my $events = get_event_types_with_coord($tokens[$i]);
		
		my $caller_record = { 
			$caller_id => {
				"caller" => $caller_id, 
				"events" => $events
			}
		};
		
		$hash{"callers"}->{$caller_id} = $caller_record->{$caller_id};
	}

	my $stop = get_end_location($hash{"info"});
	my $start = $hash{"pos"};
	$hash{"start"} = $start;
	$hash{"stop"} = $stop;	
	
	return \%hash;
}
sub show_data_by_event {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($data_href) = ($_[0]); 

	while(my ($event_id,$event_info) = each(%$data_href)) {

		#####################
		# #show number of records (events or lines) for each caller
		#####################
		# print $caller,",",$records->{"caller_count"},"\n"; 

		#####################
		# show records (events) only for one caller
		#####################
		if($event_id eq "DEL000SUR") {

			print "event id: $event_id\n";
			print "start: ", $event_info->{"start"},"\n";
			print "stop: ", $event_info->{"stop"},"\n";		
			print "number of calls: ", $event_info->{"caller_count"},"\n";	
			
			my $callers_href = 	$event_info->{"callers"};
			while(my($caller_id, $regions_href) = each(%$callers_href)) {
				my $events_href = $regions_href->{"events"};
				
				my $types_aref = $events_href->{"types"};
				my $coords_href = $events_href->{"coords"};
				while(my ($type, $regions_aref) = each %$coords_href) {
					foreach my $coord (@$regions_aref) {
						print "type: $type, chr: ", $coord->{"chr"},", start: ",$coord->{"start"},", stop: ",$coord->{"stop"},"\n";
					}
				}
			}
		}
	}

}
##########################################################################################
# 											Helper functions							 #
##########################################################################################
sub get_headers {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($str) = ($_[0]);

	my %hash = ();
	my @tmp = split(/\t+/, $str);
	for(my $i = 0; $i < scalar(@tmp); $i++) {
		$hash{lc($i)} = lc($tmp[$i]);
		$hash{lc($tmp[$i])} = lc($i);
	}
	return \%hash;
}

sub get_event_types_with_coord {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($str) = ($_[0]); 

	my ($gt,$ln,$dv,$type,$co) = split(/:/,$str);

	#event types: e.g. INS, DEL..etc
	my @types = split(/,/,$type);
	my %hash = (
		"gt" => $gt,
		"length" => $ln,
		"dv" => $dv,
		"types" => \@types
	);	
	my $coords = parse_coordinates($co);

	my %all_event_coordinates = ();
	for(my $i = 0; $i < scalar(@types); $i++) {
		insert($types[$i], $coords->[$i],\%all_event_coordinates);
	}

	$hash{"coords"} = \%all_event_coordinates;

	return \%hash;	
}
sub parse_coordinates {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($str) = ($_[0]); 
	
	my @coordinates = ();
	my @tmp = split(/,/,$str);
	foreach my $pos (@tmp) {
		my ($start,$stop) = split(/-/,$pos);
		my $index = index($start,"_");
		my $chr = substr($start,0,$index);
		$start = substr($start,$index+1);
		
		$index = index($stop,"_");
		$stop = substr($stop ,$index+1);
		
		push(@coordinates, {"chr" => $chr, "start" => $start, "stop" => $stop});
	}
	return \@coordinates;
}

sub get_end_location {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($str) = ($_[0]); 

	my @tokens = split(/;/,$str);
	my $pos = index($tokens[4],"=");
	my $k = substr($tokens[4],$pos+1);

	$pos = index($tokens[5],"=");
	my $v = substr($tokens[5],$pos+1);

	return ($k, $v);
}

sub map_technologies {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($file) = ($_[0]); 

	my $data = load_data($file);
	my %hash = ();
	foreach my $line (@$data) {
		$line = trim($line);
		
		my ($k,$v) = split(/\t+/,$line);
		$hash{$k} = $v;
	}
	return \%hash;
}
##########################################################################################
# 											common										 #
##########################################################################################
sub execute {
	my $EXIT = 1;
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($cmd, $status) = ($_[0], $_[1]); 

	$msg = "no message";
	
	my $rc = system($cmd);
	if($rc) {
		$msg = join(" ", "error: command could not execute:", $cmd, "\nLine:", __LINE__,"\nQuiting program...");
		exit_with_msg($msg) if($status == $EXIT);
	}
	
	$msg = join(" ", "error: command could not execute:", $cmd, "\nLine:", __LINE__, "\n");
	warn($msg) if($rc);
	
	return $rc;
}

sub show_msg {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	
	my ($delimiter, $array) = ($_[0], $_[1]);
	my $str = join($delimiter, @$array);
	print "$str\n";
}
sub get_files {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	
	my ($path,$match) = ($_[0], $_[1]);
	$path = trim($path);
	my @files = glob("$path/$match");
	return \@files;
}
sub file_exists {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg("not enough arguments, line: ".__LINE__) if(@_ < 1);
	
	my $file = $_[0];
	unless( -e $file) {
		warn "warning, file does not exits:\n$file\n";
		exit;
	}
}
sub path_exists {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg("not enough arguments, line: ".__LINE__) if(@_ < 1);
	
	my $path = $_[0];
	unless( -d $path) {
		warn "warning, path does not exits:$path\n";
		return 0;
	}
	return 1;
}
sub load_data {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	
	my $file = $_[0];
	
	open(IN,"<", $file) or exit_with_msg("$!, $file line: ". __LINE__);
	my @data = ();
	@data = <IN>;
	close(IN);
	
	chomp(@data);
	return \@data;
}
sub load_sequences {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($file,$format) = ($_[0],$_[1]);
	
	my @seqs = ();
	my $in  = Bio::SeqIO->new(-file => $file , -format => $format);
	while ( my $seq = $in->next_seq() ) {
    	push(@seqs, $seq);
    }
	return \@seqs;
}
sub write_sequences {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 3);
	my ($seqs,$file, $format) = ($_[0],$_[1],$_[2]);

    my $out = Bio::SeqIO->new(-file => ">$file" ,
                           -format => $format);

	foreach my $seq (@$seqs) {
        $out->write_seq($seq);
    }
}
sub trim {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	
	my $string = $_[0];
	
	#$string =~ s/^\s+|\s+$//g;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	$string =~ s/\/$//;
	
	return $string;
}
sub get_basename {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	
	my ($line,$match) = ($_[0], $_[1]);
	
	my($filename, $path, $suffix) = fileparse($line, ($match));
	$path = trim($path);
	
	return ($filename, $path, $suffix);
}
sub tolower {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($arrayref) = ($_[0]);	

	my ($counter) = (0);
	foreach my $line (@$arrayref) {
		$line = trim($line);
		$line = lc($line);
		$arrayref->[$counter] = $line;
		$counter++;
	}
}
sub touper {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($arrayref) = ($_[0]);	

	my ($counter) = (0);
	foreach my $line (@$arrayref) {
		$line = trim($line);
		$line = uc($line);
		$arrayref->[$counter] = $line;
		$counter++;
	}
}
sub get_hash {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($array) = ($_[0]);
	
	my %hash = map{$_ => 1}@$array;
	return \%hash;
}
sub unique {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 1);
	my ($data) = ($_[0]);

	my @unique = do { my %seen; grep { !$seen{$_}++ } @$data };
 	return \@unique;
 	
 	#another solution
 	# my %seen;
  	#return grep { !$seen{$_}++ } @_;
}
sub get_temp_filename {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg("not enough arguments, line: ".__LINE__) if(@_ < 1);
	
	my $path = trim($_[0]);
	
    my $fh = File::Temp->new(
        TEMPLATE => "tempXXXXX",
        DIR      => "$path",
        SUFFIX   => ".txt",
        UNLINK => 0
    );

    return $fh->filename;
}
sub insert {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 3);
	my ($g1, $g2, $network) = ($_[0],$_[1],$_[2]); 

	if(exists $network->{$g1}) {
		my $tmp = $network->{$g1};
		push(@$tmp, $g2);
		$network->{$g1} = $tmp;	
	} else {
		$network->{$g1} = [$g2];
	}
}
sub set_symmetric_difference {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($a, $b) = ($_[0], $_[1]);
	
	my $s = Set::Scalar->new(@$a);
	my $t = Set::Scalar->new(@$b);
	
	my $d = $s->symmetric_difference($t);
	return [$d->members];
}
sub set_difference {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($a, $b) = ($_[0], $_[1]);

	my $s = Set::Scalar->new(@$a);
	my $t = Set::Scalar->new(@$b);
	my $d = $s->difference($t);	#returns elements that are present in (s) only

	return [$d->members];
}

sub set_intersect {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($a, $b) = ($_[0], $_[1]);
	
	my $s = Set::Scalar->new(@$a);
	my $t = Set::Scalar->new(@$b);
	
	my $i = $s->intersection($t);	#returns elements that are present in both (s) and (t)
	return [$i->members];
}

sub set_union {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	exit_with_msg($msg) if(@_ < 2);
	my ($a, $b) = ($_[0], $_[1]);
	
	my $s = Set::Scalar->new(@$a);
	my $t = Set::Scalar->new(@$b);
	
	my $u = $s->union($t);
	return [$u->members];
}
sub exit_with_msg {
	my $msg = join(" ", "Error in function",(caller(0))[3],"\nCause: not enough arguments, line: ".__LINE__);
	$msg = $_[0] unless (@_ < 1);

	warn $msg,"\n";
	exit;
}
sub usage {
	exit_with_msg "usage: perl stat.pl < vcf file> <caller-technology map file>\n";
	exit;
}
exit;
