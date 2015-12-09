#!/usr/bin/perl

if (@ARGV == 0)
{
    print STDERR "Usage: $0 <curr1>:<base_curr1>:<bitcoincharts file1> [<curr2>:<base_curr2>:<bitcoincharts file2>] ...
takes data in the format of files here: http://api.bitcoincharts.com/v1/csv/
and converts them to a ledger format. 

Only prints the opening price per day
";
    exit -1;
}


require 'util.pl';

foreach my $arg (@ARGV)
{
    my ($curr,$base_curr,$file) = $arg =~ /^(.*?):(.*?):(.*)/ or die "Can't understand arg $arg";
    
    my $f = new IO::File;
    
    open ($f, $file) || die "Can't open $file";


    while (my $l = <$f>)
    {
	chomp $l;

	my ($seconds, $price, $volume) = split(/,/,$l);

	my $date = convertSecondsToText($seconds);

	my $ed = $curr_date_to_entry{"$curr:$base_curr:$date"};
	if((defined $ed->{seconds} ) && $ed->{seconds} < $seconds)
	{
	    next;
	}

	$ed = { date => $date, seconds => $seconds, price => $price };
	$curr_date_to_entry{"$curr:$base_curr:$date"} = $ed;
    }   
	    
}


foreach my $arg (sort keys %curr_date_to_entry)
{
    my ($curr,$base_curr,$date) = split(/:/,$arg);

    my $price = $curr_date_to_entry{$arg}->{price};
    
    print "P $date $curr $base_curr $price\n"
}

