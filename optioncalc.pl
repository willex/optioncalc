#!/usr/bin/perl

#*************************************#
#        MAX PAIN CALCULATOR          #
#                                     #
#  Version: 2.0                       #
#  Author: Alexander Wilhelm          #
#  Contact: alex.wilhelm@gmx.at       #
#*************************************#

#Perl Modules
use Finance::Quote;
use Finance::QuoteOptions;
use Data::Dumper;
use strict;
#use warnings;

###
# START INPUT

print "Enter Stock Symbol (e.g. IBM): ";
chop (my $inp_symb = uc <STDIN>);
if ( $inp_symb =~ m/[^a-zA-Z.-]/ ) { print "\nABORTED: Entered Stock Symbols not allowed. Please try again!\n"; exit 1;}
print "\n";

print "Enter option expiration month (e.g. 201010): ";
chop (my $inp_exp = <STDIN>);
if ( $inp_exp =~ m/[^0-9]/ ) { print "\nABORTED: Expiration month only numbers allowed. Please try again!\n"; exit 1;}
print "\n";

print "Select display mode\n";
print "  1: Short View\n";
print "  2: Detailed View\n";
print "  (1 or 2) default=1 : ";
chop (my $inp_detail = <STDIN>);
if ( $inp_detail =~ m/[^1-2]/ ) { print "\nABORTED: Display mode only 1 or 2 allowed. Please try again!\n"; exit 1;}
print "\n";

###
# DATA RETRIEVAL & PREPARATION

# Variables
my @work_array; # Main work array filled with final & calculated values

# Get Quote Information
my $q = Finance::Quote->new();
my %data = $q->fetch('nyse', $inp_symb);

# Get Quote Options (Put OI, Call OI, Strike Put/Call etc.)
my $q=Finance::QuoteOptions->new($inp_symb);
$q->source('yahoo');  # add cboe
die 'Retrieve Failed' unless $q->retrieve(2);

# Calls/Puts for next expiration, sorted by strike price
my @calls = sort @{$q->calls($inp_exp)};
my @puts = sort @{$q->puts($inp_exp)};
my $exp_date;

foreach (@{$q->data}) {
	if (substr($_->{exp}, 0, 6) == $inp_exp) {
		$exp_date = $_->{exp};
		last;
	}
}


# put all strike prices in temp list
my @strike_prices;
my @merge_temp;

push (@merge_temp, @calls, @puts);
my $count = @merge_temp;

for (my $i=0; $i<$count; $i++) {
	push @strike_prices, @merge_temp[$i]->{'strike'};
}

# create unique strike list
my %hashTemp = map { $_ => 1 } @strike_prices;
@strike_prices = sort { $a <=> $b } keys %hashTemp;

my $strike_itm;
foreach my $key (sort { $b <=> $a } (keys(%hashTemp)) ) {
	if ( $data{$inp_symb, 'last'} >= $key) {
		$strike_itm = $key;
		last;
	}
}

###
# FINALIZE

# reverse strike price list for calculation put
@strike_prices = reverse(@strike_prices);
@work_array = &calcMaxPain(\@work_array, \@strike_prices, \@puts, 'put');

# reverse strike price list and work array for calculation call
@strike_prices = reverse(@strike_prices);
@work_array = reverse(@work_array);
@work_array = &calcMaxPain(\@work_array, \@strike_prices, \@calls, 'call');


# Addtional Quote Information
my %quote_info = (
	"COMPANY NAME", $data{$inp_symb, 'name'},
	"SYMBOL", $inp_symb,
	"LAST PRICE", $data{$inp_symb, 'last'},
	"LAST TRADE DATE", $data{$inp_symb, 'date'},
	"LAST TRADE TIME", $data{$inp_symb, 'time'},
	"PREVIOUS CLOSE", $data{$inp_symb, 'close'},
	"EXPIRATION MONTH", $inp_exp,
	"EXPIRATION DATE", $exp_date,
	"STRIKE PRICE ITM", $strike_itm
);

# Summary Information
my @sum_max_pain =  sort { $a->{'max_pain'} <=> $b->{'max_pain'} } @work_array;

my %sum_info = (
	"MAX PAIN STRIKE", $sum_max_pain[0]->{'strike'},
	"DIFF TO CLOSE", sprintf("%.3f",$data{$inp_symb, 'close'})."        ".sprintf("%.3f", ($sum_max_pain[0]->{'strike'}-$data{$inp_symb, 'close'})*-1)." /   ".sprintf("%.2f%%", ($sum_max_pain[0]->{'strike'}-$data{$inp_symb, 'close'})/$data{$inp_symb, 'close'}*-100),
	"DIFF TO LAST",  sprintf("%.3f",$data{$inp_symb, 'last'})."        ".sprintf("%.3f", ($sum_max_pain[0]->{'strike'}-$data{$inp_symb, 'last'})*-1)." /   ".sprintf("%.2f%%", ($sum_max_pain[0]->{'strike'}-$data{$inp_symb, 'last'})/$data{$inp_symb, 'last'}*-100)
);


###
# PRINT

#create column outline
my $print_column_outline;
my $column_format_quote;
my @column_detail_main_init_header;
my $column_format_main_init_header;
my @column_detail_main_header;
my $column_format_main_header;
my $column_format_main;


$print_column_outline = "+----------------------------------------------------------------";
if ( $inp_detail == 2 ) {
	# Detail View
	$print_column_outline .= "------------------------------------+";
	$column_format_quote = "| %-17s : %-75s    |\n";
	@column_detail_main_init_header = ('CALL', '', '', '', 'PUT');
	$column_format_main_init_header = "| %50s%48s |%10s   |%14s    | %50s%48s |\n";
	@column_detail_main_header = ('Symbol', 'Bid', 'Ask', 'Last', 'Change', 'Volume', 'OpenInt', 'OpenIntVal', 'STRIKE', 'MAX PAIN', 'Symbol', 'Bid', 'Ask', 'Last', 'Change', 'Volume', 'OpenInt', 'OpenIntVal');
	$column_format_main_header = "| %-25s%8s %8s %8s %8s %10s %10s %15s |%10s   |%14s    | %-25s%8s %8s %8s %8s %10s %10s %15s |\n";
	$column_format_main = "|%25s %8s %8s %8s %8s %10s %10s %15.1f |%10s   |%14.1f    |%25s %8s %8s %8s %8s %10s %10s %15.1f |\n";
} else {
	# Simple View
	$print_column_outline .= "+";
	$column_format_quote = "| %-17s : %-39s    |\n";
	@column_detail_main_init_header = ('CALL', '', '', '', 'PUT');
	$column_format_main_init_header = "| %32s%30s |%10s   |%14s    | %30s%32s |\n";
	@column_detail_main_header = ('Symbol', 'Volume', 'OpenInt', 'OpenIntVal', 'STRIKE', 'MAX PAIN', 'Symbol', 'Volume', 'OpenInt', 'OpenIntVal');
	$column_format_main_header = "| %-25s%10s %10s %15s |%10s   |%14s    | %-25s%10s %10s %15s |\n";
	$column_format_main = "|%25s %10s %10s %15.1f |%10s   |%14.1f    |%25s %10s %10s %15.1f |\n";

}
my $print_column_middle .= "-------------+"."------------------";
my $print_column_main = $print_column_outline.$print_column_middle.$print_column_outline."\n";


# Print Quote Info
print $print_column_outline."\n";
foreach my $key (sort (keys(%quote_info))) {
	printf($column_format_quote, $key, $quote_info{$key});
}

# Print Main Table Header
print $print_column_main;
printf($column_format_main_init_header, @column_detail_main_init_header);
print $print_column_main;
printf($column_format_main_header, @column_detail_main_header);
print $print_column_main;

# Print Main Table
$count = @work_array;
for (my $i=0; $i<$count; $i++) {
	## test print
	if ( $inp_detail == 2 ) {
		printf($column_format_main, $work_array[$i]->{'call_symbol'},
									$work_array[$i]->{'call_bid'},
									$work_array[$i]->{'call_ask'},
									$work_array[$i]->{'call_last'},
									$work_array[$i]->{'call_change'},
									$work_array[$i]->{'call_volume'},
									$work_array[$i]->{'call_open'},
									$work_array[$i]->{'call_usdval'},
									$work_array[$i]->{'strike'},
									$work_array[$i]->{'max_pain'},
									$work_array[$i]->{'put_symbol'},
									$work_array[$i]->{'put_bid'},
									$work_array[$i]->{'put_ask'},
									$work_array[$i]->{'put_last'},
									$work_array[$i]->{'put_change'},
									$work_array[$i]->{'put_volume'},
									$work_array[$i]->{'put_open'},
									$work_array[$i]->{'put_usdval'});
	} else {
		printf($column_format_main, $work_array[$i]->{'call_symbol'},
									$work_array[$i]->{'call_volume'},
									$work_array[$i]->{'call_open'},
									$work_array[$i]->{'call_usdval'},
									$work_array[$i]->{'strike'},
									$work_array[$i]->{'max_pain'},
									$work_array[$i]->{'put_symbol'},
									$work_array[$i]->{'put_volume'},
									$work_array[$i]->{'put_open'},
									$work_array[$i]->{'put_usdval'});
	}
} # eof print loop
print $print_column_main;

# Print Summary Info
foreach my $key (sort (keys(%sum_info))) {
	printf($column_format_quote, $key, $sum_info{$key});
}
print $print_column_outline."\n";

exit 0;

###
# SUBS

sub calcMaxPain(\@@@$) {

	# VARIABLES -- Derefernce passed arguments
	my @_temp_work_array = @{shift()};
	my @_temp_strike_prices = @{shift()};
	my @_temp_putcall = @{shift()};
	my $_calc_action = shift;


	# get count for calls/puts and master strike price list
	my $_count = @_temp_putcall;
	my $_count_strikes = @_temp_strike_prices;

	for (my $i=0; $i<$_count_strikes; $i++) {

		$_temp_work_array[$i]->{'strike'} = @_temp_strike_prices[$i];

		# loop through calls array to add values to work array
		for (my $j=0; $j<$_count; $j++) {
			if ( @_temp_putcall[$j]->{'strike'} == @_temp_strike_prices[$i] ) {
				# add matches to work array
				$_temp_work_array[$i]->{$_calc_action.'_bid'} = @_temp_putcall[$j]->{'bid'};
				$_temp_work_array[$i]->{$_calc_action.'_ask'} = @_temp_putcall[$j]->{'ask'};
				$_temp_work_array[$i]->{$_calc_action.'_last'} = @_temp_putcall[$j]->{'last'};
				$_temp_work_array[$i]->{$_calc_action.'_change'} = @_temp_putcall[$j]->{'change'};
				$_temp_work_array[$i]->{$_calc_action.'_symbol'} = @_temp_putcall[$j]->{'symbol'};
				$_temp_work_array[$i]->{$_calc_action.'_open'} = @_temp_putcall[$j]->{'open'};
				$_temp_work_array[$i]->{$_calc_action.'_volume'} = @_temp_putcall[$j]->{'volume'};
			}
		}

		# fill empty values for calculation
		if ( @_temp_work_array[$i]->{$_calc_action.'_open'} eq undef ) {
			$_temp_work_array[$i]->{$_calc_action.'_open'} = 0;
		}

		# set initial usd val
		$_temp_work_array[0]->{$_calc_action.'_usdval'} = 0;

		my $usd_val = 0;
		# calculate open int. value
		for ( my $j=$i; $j>0; $j--) {
	       	# max pain formula
	       	$usd_val = $usd_val + ( (@_temp_work_array[$i]->{'strike'} - @_temp_work_array[$j-1]->{'strike'}) * @_temp_work_array[$j-1]->{$_calc_action.'_open'} );
	       	$_temp_work_array[$i]->{$_calc_action.'_usdval'} = abs($usd_val);
	    }

		# calculate max usd value after call run
		if ( $_calc_action eq 'call' ) {
			$_temp_work_array[$i]->{'max_pain'} = $_temp_work_array[$i]->{'call_usdval'} + $_temp_work_array[$i]->{'put_usdval'}
		}

	} # eof for loop

	## Return updated array for work array
	return @_temp_work_array;
} # eof sub
