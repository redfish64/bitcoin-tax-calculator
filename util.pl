# Copyright 2012 Rareventure, LLC
# Copyright 2015,2016 Rareventure, LLC
#
# This file is part of Bitcoin Tax Calculator
# Bitcoin Tax Calculator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# Bitcoin Tax Calculator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Bitcoin Tax Calculator.  If not, see <http://www.gnu.org/licenses/>.
#
# If you make modifications to this software that you feel
# increases it usefulness for the rest of the community, please
# email the changes, enhancements, bug fixes as well as any and
# all ideas to me. This software is going to be maintained and
# enhanced as deemed necessary by the community.
#
# Tim Engler (engler@gmail.com)


use Time::Local;



sub testConvertTextToDays
{
    $x = convertTextToDays("2011-01-01");
    for($i=0; $i < 366; $i++)
    {
	print $x.",".convertDaysToText($x).",".convertTextToDays(convertDaysToText($x))."\n";
	die unless $x == convertTextToDays(convertDaysToText($x));
	$x++;
    }
}

#converts epoch seconds to a textual date
sub convertSecondsToText
{
    my ($date_seconds) = @_;
    $date = 
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
	gmtime($date_seconds);
    $mon ++; # add 1 to month, returned in format (0..11)
    $year += 1900; 
    
    if(length $mon == 1) {
	$mon = "0".$mon;
    }
    if(length $mday == 1) {
	$mday = "0".$mday;
    }
    if(length $year == 1) {
	$year = "0".$year;
    }
    $date = "$year-$mon-$mday";
}

#converts the days to yyyy/mm/dd
sub convertDaysToText
{
	my $date_days = shift;
	my $date_seconds = $date_days * 24 * 3600;
	my ($date,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

	if ($date_seconds != 0) {
	    $date = convertSecondsToText($date_seconds);
	}
	
	return $date;
}


#converts dd-mmm-yyyy or mm-dd-yyyy to days
sub convertTextToDays
{
    my $month_list = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    
    $_ = shift;

    # 31-JAN-2003
    if (/^([0-9]{1,2})[-,\/]([A-Z]{3})[-,\/]([0-9]{2,4})$/) {
	my $month_text = $2;
	my $day = $1;
	my $year = $3;

	for($month = 0; $month < 12; $month++)
	{
	    if($month_list->[$month] eq $month_text)
	    {
		last;
	    }
	}

	die "Couldn't understand month $month_text" if $month == 12;
	
	if($month < 0 || $month > 11 || $day < 1 || $day > 31)  {
	    return 0; #not a valid date
	}
	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }
    
    # 01-31-2003
    if(/^([0-9]{2})[-\/]([0-9]{2})[-\/]([0-9]{4})$/)
    {
	my ($month, $day, $year) = ($1, $2, $3);

	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }

    # 2003-01-31
    if(/^([0-9]{4})[-\/]([0-9]{2})[-\/]([0-9]{2})$/)
    {
	my ($year, $month, $day) = ($1, $2, $3);

	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }

    # not a valid date
    die "What is $_";
}



#if numbers are equal enough to match diff
sub about_equal
{
    my ($n1, $n2, $diff) = @_;

    if($n1 - $n2 > $diff || $n2 - $n1 > $diff)
    {
	return 0; #false
    }

    return 1; #about equal
}

sub bigrat
{
    return new Math::BigRat($_[0]) if defined $_[0];

    return undef;
}


sub format_amt
{
    my ($v, $acc) = @_;
    $acc = 12 unless defined $acc;
    
    #as_float() returns a float that has $acc digits (not a regular c float)
    return sprintf("%12.${acc}f",$v->as_float($acc));
}

1;
